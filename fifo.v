module fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3          // 3 bits -> 8 memory slots
)(
    input  wire clk,
    input  wire rst,
    input  wire wr_en,
    input  wire rd_en,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];   // the memory array
    reg [ADDR_WIDTH:0] wr_ptr;   // note: ADDR_WIDTH:0 -> one bit wider
    reg [ADDR_WIDTH:0] rd_ptr;

    // write logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;   // use only the lower bits to address memory
            wr_ptr <= wr_ptr + 1;
        end
    end

    // read logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr <= 0;
            dout   <= 0;
        end else if (rd_en && !empty) begin
            dout   <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // full/empty logic
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) &&
                   (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]);
    // assertion: full and empty should never both be true at once
    always @(posedge clk) begin
        if (!rst)
            assert (!(full && empty))
        else $error("ASSERTION FAILED: full and empty are both true at time %0t", $time);
end

endmodule
