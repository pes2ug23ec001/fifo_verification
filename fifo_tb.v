module fifo_tb;
    reg clk = 0;
    reg rst = 1;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [7:0] din = 0;
    wire [7:0] dout;
    wire full, empty;

    integer i;
    reg [7:0] rand_data;

    reg saw_full = 0;
    reg saw_empty = 0;
    reg saw_partial = 0;

    reg [7:0] sb_mem [0:63];
    integer sb_wr_ptr = 0;
    integer sb_rd_ptr = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(3)) uut (
        .clk(clk), .rst(rst),
        .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout),
        .full(full), .empty(empty)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (full)             saw_full    <= 1;
        if (empty)            saw_empty   <= 1;
        if (!full && !empty)  saw_partial <= 1;
    end

    always @(posedge clk) begin
        if (!rst)
            assert (!(full && empty))
            else $error("ASSERTION FAILED: full and empty are both true at time %0t", $time);
    end

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, fifo_tb);

        #10 rst = 0;
        $display("After reset: empty=%b full=%b", empty, full);

        $display("Attempting read while empty...");
        read_data();

        write_data(8'h01);
        write_data(8'h02);
        write_data(8'h03);
        write_data(8'h04);
        write_data(8'h05);
        write_data(8'h06);
        write_data(8'h07);
        write_data(8'h08);

        $display("Attempting write while full...");
        write_data(8'hFF);

        read_data();
        read_data();
        read_data();
        read_data();
        read_data();
        read_data();
        read_data();
        read_data();

        $display("Starting randomized testing...");
        for (i = 0; i < 50; i = i + 1) begin
            @(posedge clk);
            rand_data = $random;
            if ($random % 2 == 0 && !full) begin
                din   = rand_data;
                wr_en = 1;
                rd_en = 0;
                sb_mem[sb_wr_ptr] = rand_data;
                sb_wr_ptr = sb_wr_ptr + 1;
            end else if (!empty) begin
                rd_en = 1;
                wr_en = 0;
            end else begin
                wr_en = 0;
                rd_en = 0;
            end
            @(posedge clk);
            if (wr_en) begin
                wr_en = 0;
                $display("Wrote: %h | empty=%b full=%b", rand_data, empty, full);
            end
            if (rd_en) begin
                rd_en = 0;
                if (sb_rd_ptr < sb_wr_ptr) begin
                    if (dout === sb_mem[sb_rd_ptr]) begin
                        pass_count = pass_count + 1;
                        $display("Read: %h | expected: %h | PASS", dout, sb_mem[sb_rd_ptr]);
                    end else begin
                        fail_count = fail_count + 1;
                        $display("Read: %h | expected: %h | *** FAIL ***", dout, sb_mem[sb_rd_ptr]);
                    end
                    sb_rd_ptr = sb_rd_ptr + 1;
                end
            end
        end
        wr_en = 0;
        rd_en = 0;

        #20;
        $display("---- Scoreboard Summary ----");
        $display("  PASS: %0d", pass_count);
        $display("  FAIL: %0d", fail_count);

        $display("---- Coverage Report ----");
        $display("  Hit FULL state:                        %s", saw_full    ? "YES" : "NO");
        $display("  Hit EMPTY state:                       %s", saw_empty   ? "YES" : "NO");
        $display("  Hit PARTIAL (neither full nor empty):  %s", saw_partial ? "YES" : "NO");

        #20 $finish;
    end

    task write_data(input [7:0] data);
        begin
            @(posedge clk);
            din = data;
            wr_en = 1;
            if (!full) begin
                sb_mem[sb_wr_ptr] = data;
                sb_wr_ptr = sb_wr_ptr + 1;
            end
            @(posedge clk);
            wr_en = 0;
            $display("Wrote: %h | empty=%b full=%b", data, empty, full);
        end
    endtask

    task read_data;
        begin
            @(posedge clk);
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;

            if (sb_rd_ptr < sb_wr_ptr) begin
                if (dout === sb_mem[sb_rd_ptr]) begin
                    pass_count = pass_count + 1;
                    $display("Read: %h | expected: %h | PASS", dout, sb_mem[sb_rd_ptr]);
                end else begin
                    fail_count = fail_count + 1;
                    $display("Read: %h | expected: %h | *** FAIL ***", dout, sb_mem[sb_rd_ptr]);
                end
                sb_rd_ptr = sb_rd_ptr + 1;
            end else begin
                $display("Read: %h | (empty FIFO, no check needed) | empty=%b full=%b", dout, empty, full);
            end
        end
    endtask

endmodule
