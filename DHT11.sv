`timescale 1ns / 1ps

module DHT11(
    input logic clk,          // �������� ������ 100 ���
    input logic rst_n,        // ������ ������
    input logic uart_rx,      // ������� ������ UART ��� ������� ������
    output logic uart_tx,     // �������� ������ UART ��� �������� ������
    inout logic dht11_data,   // ������������� ����� ��� ������ � DHT11
    output logic ready        // ������ ���������� ������
);

    // ���������
    parameter CLK_FREQ = 100000000; // ������� ��������� (100 ���)
    parameter DHT11_START_DELAY = 100000000; // 1 sec
    parameter BAUD_RATE = 9600; // �������� �������� UART ���/���
    parameter DHT11_RESPONSE_TIME = 80000000; // ����� �������� ������ DHT11 ( ��� 80 ���)
    parameter DHT11_DATA_BITS = 40; // ���������� ��� ������
    parameter DHT11_DELAY = 18000; // �������� �� 18 �� � ������
    parameter TIMEOUT = 10000; // ������� ��� �������� ������ (� ������)

    // ��������� ��� ��������� ���������� (��������� 0 � 1)
   parameter LOW_DURATION = 5000000; // 50 ����������� ��� 100 ���
   parameter HIGH_DURATION_0 = 2800000; // 28 ����������� ��� 100 ���
   parameter HIGH_DURATION_1 = 7000000; // 70 ����������� ��� 100 ���


    // ��������� ��
    typedef enum logic [2:0] {
        IDLE,
        START,
        WAIT_RESPONSE,
        READ_DATA,
        SEND_DATA,
        ERROR,
        UART_SEND
    } state_t; // ����� ��� ������

    state_t state, next_state;

    // �������� ��� ��������
    logic [26:0] counter; // 1 sec - 27 bit
    logic [5:0] data_counter; // ������� ������ (����������� ���������� ��������� ��� ������)
    logic [15:0] bit_counter; // ������� ��� ������������ ���������

    // �������� ������
    logic [7:0] humidity_integer;
    logic [7:0] temperature_integer;
    logic [DHT11_DATA_BITS-1:0] data_buffer; // ������ 40 ���
    logic [7:0] checksum; // ����������� ����� (��������� 8 ���)

    // ������� ��� ���������� DHT11
    logic start_signal;
    logic dht11_ready;
    logic data_bit_ready; // ������, �����������, ��� ��� ������ �����
    logic last_data_line; // ��������� ��������� ����� ������

    // ������ ��� �������� ����� UART
    logic [15:0] uart_data; // ������ ��� �������� ����� UART
    logic send_uart; // ������ ��� �������� ������
    logic uart_busy; // ������, �����������, ��� UART �����
    logic [4:0] bit_index; // ������ �������� ���� ��� ��������
    logic [15:0] uart_shift_reg; // ��������� ������� ��� �������� ������

    // ������ ���������� dht11_data
    logic dht11_data_output; // ������ ��� ���������� ������������ (0 ��� ����, 1 - �����)
    logic dht11_data_internal; // ���������� ������ ��� ���������� �������

    // ��������� dht11_data �� ����� (tri-state ������)
    assign dht11_data = dht11_data_output ? dht11_data_internal : 1'bz; 

    // ��������� � ��������
    always_ff @(posedge clk or negedge rst_n) begin // ��� ����������� ��������
        if (!rst_n) begin
            state <= IDLE; // ����� ��������
            counter <= 0; // ����� ��������
            ready <= 0; // ������ ����������
            data_buffer <= 0; // ����� ������ ������
            humidity_integer <= 0;
            temperature_integer <= 0;
            data_counter <= 0;
            bit_counter <= 0;
            last_data_line <= 1; // �������������� � ������� ���������
            send_uart <= 0; // ������ �������� ������
            uart_data <= 0; // ������ ��� �������� � UART
            uart_busy <= 0; // ���������� UART �� �����
            bit_index <= 0; // ������ ����� ��� ��������
            dht11_data_output <= 0; // ���������� dht11_data �� ����
            dht11_data_internal <= 0; // ���������� �������� ������ DHT11
        end 
        else begin
        state <= next_state;

            // ���������� ���������
            if (state == START || state == WAIT_RESPONSE || state == READ_DATA || state == UART_SEND) begin
                counter <= counter + 1;
            end 
            else begin
                counter <= 0;
            end

            // ���������� ��������� ����� ������
            if (state == READ_DATA) begin
                if (dht11_data == 0) begin
                    if (last_data_line == 1) begin
                        bit_counter <= 0;
                    end
                    bit_counter <= bit_counter + 1;
                end else if (dht11_data == 1 && last_data_line == 0) begin
                    if (bit_counter > LOW_DURATION) begin
                        // ����������� �����
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
    

            // ������ �������� ������ ����� UART
            if (state == UART_SEND) begin
                if (!uart_busy) begin
                    uart_shift_reg <= {uart_data}; //  ������ 16 ���
                    bit_index <= 0; // �������� � ������� ����
                    uart_busy <= 1; // ������������� ������ ���������
                end 
                else if (counter >= (CLK_FREQ / BAUD_RATE)) begin
                    uart_tx <= uart_shift_reg[0]; // �������� ������� ���
                    uart_shift_reg <= {1'b0, uart_shift_reg[15:1]}; // �������� ������� �� 1 ���
                    bit_index <= bit_index + 1; // ��������� � ���������� ����
                    if (bit_index == 16) begin
                        uart_busy <= 0; // ��������� ��������
                        ready <= 1;
                        send_uart <= 0; // ���������� ������ ��������
                    end
                end
            end
        end
    
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ������ ��������� ���������; ����������� ������, ����� �������� ������� �������
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
            // ��� 2
            if (counter >= DHT11_START_DELAY) begin  // 1 sec (100000000 � ������)
            //counter <= 0;
            dht11_data_output = 1;
            dht11_data_internal = 0;
            if (counter >= DHT11_DELAY+DHT11_START_DELAY) begin // DHT11_START_DELAY=18000 - �������� �� 18 �� � ������
                    //counter <= 0;
                    dht11_data_output = 0; // ����������� � ����� ������ ������ �� �������
                    next_state = WAIT_RESPONSE;
                end
            end  
            end
            WAIT_RESPONSE: begin
            if (dht11_data == 0) begin
                // ���� ����� ������ ������, ���� 80 ���
                if (counter >= DHT11_RESPONSE_TIME+DHT11_DELAY+DHT11_START_DELAY) begin // // DHT11_RESPONSE_TIME=80000000 - ����� �������� ������ DHT11 ( ��� 80 ���)
                    //counter <= 0; // ���������� �������
                    // ����� ������� �������, ���� �������
                end
            end else if (dht11_data == 1) begin
                // ���� ����� ������ �������, ������ DHT11 ����� �������� ������
                if (counter >= DHT11_RESPONSE_TIME+DHT11_RESPONSE_TIME+DHT11_DELAY+DHT11_START_DELAY) begin
                    //counter <= 0; // ���������� �������
                    next_state = READ_DATA; // ������� � ������ ������
                end
            end
        end
            READ_DATA: begin
                if (data_counter >= DHT11_DATA_BITS) begin
                    next_state = SEND_DATA;
                end
                if (counter >= TIMEOUT) begin
                    next_state = ERROR; // �������
                 end
            end
            SEND_DATA: begin
                if (uart_rx) begin
                    // ���� ������ ������ 1 �� UART, ���������� ������
                    if (uart_rx == 1) begin
                        humidity_integer = data_buffer[7:0]; // ���������
                        temperature_integer = data_buffer[23:16]; // �����������
                        checksum = data_buffer[39:32]; // ����������� �����
                        if (checksum == (humidity_integer + temperature_integer)) begin
                            uart_data = {temperature_integer, humidity_integer}; // ��������� 16 ��� ��� ��������
                        end else begin
                            uart_data = 16'h0000; // ���� ����������� ����� �������, ���������� 0
                        end
                        send_uart = 1; // ������������� ������ �������� ������
                        next_state = UART_SEND; // ��������� � ��������� �������� ������
                    end else begin
                        uart_data = 16'h0000; // ���� ������ �� 1, ���������� 0
                        send_uart = 1; // ������������� ������ �������� ������
                        next_state = UART_SEND; // ��������� � ��������� �������� ������
                    end
                end
            end
            UART_SEND: begin
                // ������ �������� ����� UART ��� ����������� � �������� ��������
                if (!uart_busy) begin
                    next_state = IDLE; // ������������ � ��������� �������� ����� ���������� ��������
                end
            end
            ERROR: begin
                uart_data = 16'h0000; // ���������� 0 � ������ ������
                send_uart = 1; // ������������� ������ �������� ������
                next_state = UART_SEND; // ��������� � ��������� �������� ������
            end
        endcase
    end

endmodule
