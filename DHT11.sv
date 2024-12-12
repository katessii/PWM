`timescale 1ns / 1ps

module DHT11(
    input logic clk,          // Тактовый сигнал 100 МГц
    input logic rst_n,        // Сигнал сброса
    input logic uart_rx,      // Входной сигнал UART для запроса данных
    output logic uart_tx,     // Выходной сигнал UART для передачи данных
    inout logic dht11_data,   // Двухсторонний вывод для работы с DHT11
    output logic ready        // Сигнал готовности данных
);

    // Параметры
    parameter CLK_FREQ = 100000000; // Частота кристалла (100 МГц)
    parameter DHT11_START_DELAY = 100000000; // 1 sec
    parameter BAUD_RATE = 9600; // Скорость передачи UART бит/сек
    parameter DHT11_RESPONSE_TIME = 80000000; // Время ожидания ответа DHT11 ( для 80 мкс)
    parameter DHT11_DATA_BITS = 40; // Количество бит данных
    parameter DHT11_DELAY = 18000; // Задержка на 18 мс в тактах
    parameter TIMEOUT = 10000; // Таймаут для ожидания данных (в тактах)

    // Константы для временных интервалов (кодировка 0 и 1)
   parameter LOW_DURATION = 5000000; // 50 микросекунд при 100 МГц
   parameter HIGH_DURATION_0 = 2800000; // 28 микросекунд при 100 МГц
   parameter HIGH_DURATION_1 = 7000000; // 70 микросекунд при 100 МГц


    // Состояния КА
    typedef enum logic [2:0] {
        IDLE,
        START,
        WAIT_RESPONSE,
        READ_DATA,
        SEND_DATA,
        ERROR,
        UART_SEND
    } state_t; // новый тип данных

    state_t state, next_state;

    // Счетчики для задержек
    logic [26:0] counter; // 1 sec - 27 bit
    logic [5:0] data_counter; // счетчик данных (отслеживает количество считанных бит данных)
    logic [15:0] bit_counter; // Счетчик для длительности импульсов

    // Хранение данных
    logic [7:0] humidity_integer;
    logic [7:0] temperature_integer;
    logic [DHT11_DATA_BITS-1:0] data_buffer; // вектор 40 бит
    logic [7:0] checksum; // Контрольная сумма (последние 8 бит)

    // Сигналы для управления DHT11
    logic start_signal;
    logic dht11_ready;
    logic data_bit_ready; // Сигнал, указывающий, что бит данных готов
    logic last_data_line; // Последнее состояние линии данных

    // Сигнал для передачи через UART
    logic [15:0] uart_data; // Данные для передачи через UART
    logic send_uart; // Сигнал для отправки данных
    logic uart_busy; // Сигнал, указывающий, что UART занят
    logic [4:0] bit_index; // Индекс текущего бита для передачи
    logic [15:0] uart_shift_reg; // Сдвиговый регистр для передачи данных

    // Логика управления dht11_data
    logic dht11_data_output; // Сигнал для управления направлением (0 это вход, 1 - выход)
    logic dht11_data_internal; // Внутренний сигнал для управления данными

    // Установка dht11_data на выход (tri-state логика)
    assign dht11_data = dht11_data_output ? dht11_data_internal : 1'bz; 

    // Состояние и переходы
    always_ff @(posedge clk or negedge rst_n) begin // для синхронного процесса
        if (!rst_n) begin
            state <= IDLE; // режим ожидания
            counter <= 0; // сброс счетчика
            ready <= 0; // сигнал готовности
            data_buffer <= 0; // сброс буфера данных
            humidity_integer <= 0;
            temperature_integer <= 0;
            data_counter <= 0;
            bit_counter <= 0;
            last_data_line <= 1; // Инициализируем в высоком состоянии
            send_uart <= 0; // Сигнал отправки данных
            uart_data <= 0; // Данные для отправки в UART
            uart_busy <= 0; // Изначально UART не занят
            bit_index <= 0; // Индекс битов для передачи
            dht11_data_output <= 0; // Изначально dht11_data на вход
            dht11_data_internal <= 0; // Изначально значение данных DHT11
        end 
        else begin
        state <= next_state;

            // Управление счетчиком
            if (state == START || state == WAIT_RESPONSE || state == READ_DATA || state == UART_SEND) begin
                counter <= counter + 1;
            end 
            else begin
                counter <= 0;
            end

            // Обновление состояния линии данных
            if (state == READ_DATA) begin
                if (dht11_data == 0) begin
                    if (last_data_line == 1) begin
                        bit_counter <= 0;
                    end
                    bit_counter <= bit_counter + 1;
                end else if (dht11_data == 1 && last_data_line == 0) begin
                    if (bit_counter > LOW_DURATION) begin
                        // Определение битов
                        if (bit_counter < (LOW_DURATION + HIGH_DURATION_0)) begin
                        data_buffer[data_counter] <= 0;
                        end else if (bit_counter < (LOW_DURATION + HIGH_DURATION_1)) begin
                            data_buffer[data_counter] <= 1;
                        end
                        data_counter <= data_counter + 1;
                    end
                    bit_counter <= 0;
                end
                last_data_line <= dht11_data;
            end
        end
    

            // Логика передачи данных через UART
            if (state == UART_SEND) begin
                if (!uart_busy) begin
                    uart_shift_reg <= {uart_data}; //  данные 16 бит
                    bit_index <= 0; // Начинаем с первого бита
                    uart_busy <= 1; // Устанавливаем сигнал занятости
                end 
                else if (counter >= (CLK_FREQ / BAUD_RATE)) begin
                    uart_tx <= uart_shift_reg[0]; // Передаем текущий бит
                    uart_shift_reg <= {1'b0, uart_shift_reg[15:1]}; // Сдвигаем регистр на 1 бит
                    bit_index <= bit_index + 1; // Переходим к следующему биту
                    if (bit_index == 16) begin
                        uart_busy <= 0; // Завершаем передачу
                        ready <= 1;
                        send_uart <= 0; // Сбрасываем сигнал отправки
                    end
                end
            end
        end
    
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Логика переходов состояний; выполняется всегда, когда меняются входные сигналы
    always_comb begin
        next_state = state;
        case (state)
           IDLE: begin
           ready <= 0;
                if (uart_rx) begin
                    next_state = START;
                end
            end
            START: begin
            // шаг 2
            if (counter >= DHT11_START_DELAY) begin  // 1 sec (100000000 в тактах)
            //counter <= 0;
            dht11_data_output = 1;
            dht11_data_internal = 0;
            if (counter >= DHT11_DELAY+DHT11_START_DELAY) begin // DHT11_START_DELAY=18000 - Задержка на 18 мс в тактах
                    //counter <= 0;
                    dht11_data_output = 0; // Переключаем в режим чтения данных от датчика
                    next_state = WAIT_RESPONSE;
                end
            end  
            end
            WAIT_RESPONSE: begin
            if (dht11_data == 0) begin
                // Если линия данных низкая, ждем 80 мкс
                if (counter >= DHT11_RESPONSE_TIME+DHT11_DELAY+DHT11_START_DELAY) begin // // DHT11_RESPONSE_TIME=80000000 - Время ожидания ответа DHT11 ( для 80 мкс)
                    //counter <= 0; // Сбрасываем счетчик
                    // После низкого сигнала, ждем высокий
                end
            end else if (dht11_data == 1) begin
                // Если линия данных высокая, значит DHT11 готов передать данные
                if (counter >= DHT11_RESPONSE_TIME+DHT11_RESPONSE_TIME+DHT11_DELAY+DHT11_START_DELAY) begin
                    //counter <= 0; // Сбрасываем счетчик
                    next_state = READ_DATA; // Переход к чтению данных
                end
            end
        end
            READ_DATA: begin
                if (data_counter >= DHT11_DATA_BITS) begin
                    next_state = SEND_DATA;
                end
                if (counter >= TIMEOUT) begin
                    next_state = ERROR; // Таймаут
                 end
            end
            SEND_DATA: begin
                if (uart_rx) begin
                    // Если пришел сигнал 1 от UART, отправляем данные
                    if (uart_rx == 1) begin
                        humidity_integer = data_buffer[7:0]; // Влажность
                        temperature_integer = data_buffer[23:16]; // Температура
                        checksum = data_buffer[39:32]; // Контрольная сумма
                        if (checksum == (humidity_integer + temperature_integer)) begin
                            uart_data = {temperature_integer, humidity_integer}; // Формируем 16 бит для передачи
                        end else begin
                            uart_data = 16'h0000; // Если контрольная сумма неверна, отправляем 0
                        end
                        send_uart = 1; // Устанавливаем сигнал отправки данных
                        next_state = UART_SEND; // Переходим в состояние передачи данных
                    end else begin
                        uart_data = 16'h0000; // Если сигнал не 1, отправляем 0
                        send_uart = 1; // Устанавливаем сигнал отправки данных
                        next_state = UART_SEND; // Переходим в состояние передачи данных
                    end
                end
            end
            UART_SEND: begin
                // Логика передачи через UART уже реализована в основном процессе
                if (!uart_busy) begin
                    next_state = IDLE; // Возвращаемся в состояние ожидания после завершения передачи
                end
            end
            ERROR: begin
                uart_data = 16'h0000; // Отправляем 0 в случае ошибки
                send_uart = 1; // Устанавливаем сигнал отправки данных
                next_state = UART_SEND; // Переходим в состояние передачи данных
            end
        endcase
    end

endmodule
