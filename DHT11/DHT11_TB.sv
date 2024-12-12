`timescale 1ns / 1ps



module DHT11_TB;
    // Параметры
    parameter CLK_PERIOD = 10; // Период тактового сигнала (100 МГц)

    // Тестовые сигналы
    logic clk;
    logic rst_n;
    logic uart_rx;
    logic [15:0] uart_tx;
    logic ready;
    logic dht11_data_output;
    logic dht11_data_internal;
    reg [39:0] data_sequence;
    tri dht11_data;
    

    // Подключаем модуль
    DHT11 uut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .dht11_data(dht11_data),
        .ready(ready)
    );
    
    
    // Используем tri для inout
   
    assign dht11_data = dht11_data_output ? dht11_data_internal : 'bz;

        initial begin // выполняется единожды
        rst_n = 0;
        #10000;
        rst_n = 1;
        end
        


    // Генерация тактового сигнала
    initial begin // выполняется единожды
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk; // генерация тактового сигнала
    end

// имитация работы UART
   initial begin
   uart_rx = 0;
   #100000;
   uart_rx = 1; // посылаем 1 микроконтроллеру, чтобы получить 16 бит (8 бит температуры и 8 бит влажности)
   //#20000;
   //wait(ready == 1);
   end

    // Имитация работы датчика DHT11
    initial begin
    
        #10000; // Ждем 1 usec, чтобы DHT11 стабилизировался
        dht11_data_output = 0; // устанавливаем на вход
        
        // Ожидаем команду 0 от микроконтроллера
         #17_000_000;
         wait(dht11_data == 0);
         #10_000_000;
          // Минимальная задержка перед чтением
            
         // Ответ DHT11
         dht11_data_output = 1; // Устанавливаем на выход
         
         dht11_data_internal = 0; // Передаем низкий сигнал
         #80_000; // Низкий сигнал (80 мкс)

         dht11_data_internal = 1; // Передаем высокий сигнал
         #80_000; // Высокий сигнал (80 мкс)

          // Будем передавать такую последовательность бит: 00110101_00000000_00011000_00000000_01001101
          data_sequence = 40'b0011010100000000000110000000000001001101;
            for (int i = 0; i < 40; i++) begin
                if (data_sequence[i] == 0) begin
                    // Передаем бит '0'
                    dht11_data_internal = 1; // Устанавливаем низкий уровень
                    #50_000; // Удерживаем высокий уровень (50 мс)
                    dht11_data_internal = 0; // Устанавливаем высокий уровень
                    #28_000; // Задержка для завершения бита '0' (26-28 мс)
                end else begin
                    // Передаем бит '1'
                    dht11_data_internal = 0; // Устанавливаем низкий уровень
                    #50_000; // Низкий уровень (50 мс)
                    dht11_data_internal = 1; // Устанавливаем высокий уровень
                    #70_000; // Задержка для завершения бита '1' (70 мс)
                end
            end

            // Ожидание перед следующей итерацией цикла обмена
            #50 $finish;
        end
 
    // Отображение значений в процессе симуляции
    /*initial begin
       //forever #(CLK_PERIOD / 2) clk = ~clk; // генерация тактового сигнала
        $monitor(" uart_tx: %b | dht11_data: %b | data_sequence: %b", uart_tx, dht11_data, data_sequence);
        //$monitor(" uart_tx: %b | dht11_data: %b | data_sequence: %b | counter: %d", uart_tx, dht11_data, data_sequence, uut.counter);
    end*/
endmodule