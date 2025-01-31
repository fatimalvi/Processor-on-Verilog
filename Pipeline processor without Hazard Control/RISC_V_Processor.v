`include "MUX.v"
// `include "MUX_3_1.v"
`include "adder.v"
`include "alu_64.v"
`include "alu_control.v"
`include "control_unit.v"
`include "data_memory.v"
`include "ex_mem.v"
`include "forwarding_unit.v"
`include "id_ex.v"
`include "if_id.v"
`include "immediate_generator.v"
`include "instruction_memory.v"
`include "instruction_parser.v"
`include "mem_wb.v"
`include "program_counter.v"
`include "reg_file.v"

module RISC_V_Processor(
    input clk, reset
);
    wire [63: 0] ALUresult, Adder1Out, Adder2Out, EX_MEM_ALU_Out, EX_MEM_MUX_ForwardB, EX_MEM_PC_Adder, ID_EX_Immediate, ID_EX_PC_Out, ID_EX_ReadData1;
    wire [63: 0] ID_EX_ReadData2, IF_ID_PC_Out, MEM_WB_ALU_Out, MEM_WB_Read_Data, MEM_WB_WriteData, MuxALUOut, MuxMemOut, PC_In, PC_Out, ReadData1, ReadData2;
    wire [63: 0] ReadDataMem, Read_Data, WriteData, data_out, data_out_c1, data_out_c2, imm_data, out1, result;
    
    wire [31: 0] instruction, IF_ID_Instruction;
    
    wire [ 6: 0] Opcode, funct7;
    
    wire [ 4: 0] EX_MEM_rd, ID_EX_rd, ID_EX_rs1, ID_EX_rs2, MEM_WB_rd, rd, rs1, rs2;
    
    wire [ 3: 0] Funct, Operation, ID_EX_Instruction, IF_ID_Instruction_EX;
    
    wire [ 2: 0] funct3;
    
    wire [ 1: 0] ALUOp, Forward_A, Forward_B, ID_EX_ALUOp;
    
    wire ALUSrc, Branch, EX_MEM_Branch, EX_MEM_MemRead, EX_MEM_MemWrite, EX_MEM_MemtoReg, EX_MEM_RegWrite, EX_MEM_Zero, ID_EX_ALUSrc, ID_EX_Branch;
    wire ID_EX_MemRead, ID_EX_MemWrite, ID_EX_MemtoReg, ID_EX_RegWrite, MEM_WB_MemtoReg, MEM_WB_RegWrite, MemRead, MemWrite, MemtoReg, RegWrite;

    Program_Counter PC(
            .clk(clk),
            .reset(reset),
            .PC_In(PC_In),
            .PC_Out(PC_Out)
        );
    
    Adder add1(
            .a(64'd4),
            .b(PC_Out),
            .c(Adder1Out)
        );

    Instruction_Memory iMem(
            .Inst_address(PC_Out),
            .Instruction(instruction)
        );

    IF_ID if_id(
            .clk(clk),
            .reset(reset),
            .Instruction(instruction),
            .PC_Out(PC_Out),
            .IF_ID_Instruction(IF_ID_Instruction),
            .IF_ID_PC_Out(IF_ID_PC_Out)
        );

    instruction_parser iParser(
            .instruction(instruction),
            .opcode(Opcode),
            .rd(rd),
            .rs1(rs1),
            .rs2(rs2),
            .funct3(funct3),
            .funct7(funct7)
        );

    Control_Unit c1(
            .Opcode(Opcode),
            .Branch(Branch), 
            .MemRead(MemRead), 
            .MemtoReg(MemtoReg), 
            .MemWrite(MemWrite), 
            .ALUSrc(ALUSrc), 
            .RegWrite(RegWrite), 
            .ALUOp(ALUOp)
        );

    immediate_generator Igen(
            .instruction(IF_ID_Instruction),
            .immed_value(imm_data)
        );
    
    registerFile rFile(
            .WriteData(MuxMemOut), 
            .rs1(rs1), 
            .rs2(rs2), 
            .rd(rd), 
            .clk(clk), 
            .reset(reset), 
            .RegWrite(RegWrite), 
            .ReadData1(ReadData1),
            .ReadData2(ReadData2)
        );

    assign IF_ID_Instruction_EX = {
            IF_ID_Instruction[30],
            IF_ID_Instruction[14:12]
        };

    ID_EX id_ex(
            .clk(clk),
            .reset(reset),
            
            .ALU_Op(ALUOp),
            .Branch(Branch),
            .MemRead(MemRead),
            .MemtoReg(MemtoReg),
            .MemWrite(MemWrite),
            .ALUSrc(ALUSrc),
            .RegWrite(RegWrite),
            
            .IF_ID_Ins(IF_ID_Instruction_EX),
            .IF_ID_rs1(rs1),
            .IF_ID_rs2(rs2),
            .IF_ID_rd(rd),
            .IF_ID_Immediate(imm_data),
            .IF_ID_ReadData1(ReadData1),
            .IF_ID_ReadData2(ReadData2),
            .IF_ID_PC_Out(IF_ID_PC_Out),
            
            .ID_EX_ALU_Op(ID_EX_ALUOp),
            .ID_EX_Branch(ID_EX_Branch),
            .ID_EX_MemRead(ID_EX_MemRead),
            .ID_EX_MemtoReg(ID_EX_MemtoReg),
            .ID_EX_MemWrite(ID_EX_MemWrite),
            .ID_EX_ALUSrc(ID_EX_ALUSrc),
            .ID_EX_RegWrite(ID_EX_RegWrite),

            .ID_EX_Ins(ID_EX_Instruction),
            .ID_EX_rs1(ID_EX_rs1),
            .ID_EX_rs2(ID_EX_rs2),
            .ID_EX_rd(ID_EX_rd),
            .ID_EX_Immediate(ID_EX_Immediate),
            .ID_EX_ReadData1(ID_EX_ReadData1),
            .ID_EX_ReadData2(ID_EX_ReadData2),
            .ID_EX_PC_Out(ID_EX_PC_Out)
        );

    Adder add2(
            .a(ID_EX_PC_Out),
            .b(ID_EX_Immediate << 1),
            .c(out1)
        );
    
    MUX_3_1 muxBranch1(
            .A(ID_EX_ReadData1),
            .B(MEM_WB_WriteData),
            .C(EX_MEM_ALU_Out),
            .O(data_out_c1),
            .S(Forward_A)
    );

    MUX_3_1 muxBranch2(
            .A(ID_EX_ReadData2),
            .B(MEM_WB_WriteData),
            .C(EX_MEM_ALU_Out),
            .O(data_out_c2),
            .S(Forward_B)
    );

    MUX muxBranch(
            .A(data_out_c2),
            .B(ID_EX_Immediate),
            .O(data_out),
            .S(ID_EX_ALUSrc)
        );
    
    ALU_Control ac1(
            .ALUOp(ID_EX_ALUOp),
            .Funct(ID_EX_Instruction),
            .Operation(Operation)
        );
    
    MUX muxALUSrc(
            .B(ReadData2),
            .A(imm_data),
            .O(MuxALUOut),
            .S(ALUSrc)
        );

    ALU_64_bit ALU64(
            .A(data_out_c1),
            .B(data_out),
            .Operation(Operation),
            .funct3(funct3),
            .Zero(zero), 
            .O(result)
        );

    F_Unit f1(
            .ID_EX_rs1(ID_EX_rs1),
            .ID_EX_rs2(ID_EX_rs2),
            .EX_MEM_rd(EX_MEM_rd),
            .EX_MEM_RegWrite(EX_MEM_RegWrite),
            .MEM_WB_rd(MEM_WB_rd),
            .MEM_WB_RegWrite(MEM_WB_RegWrite),
            .Forward_A(Forward_A),
            .Forward_B(Forward_B)
        );

    EX_MEM b3(
            .clk(clk),
            .reset(reset),
            
            .ID_EX_Branch(ID_EX_Branch),
            .ID_EX_MemRead(ID_EX_MemRead),
            .ID_EX_MemWrite(ID_EX_MemWrite),
            .ID_EX_RegWrite(ID_EX_RegWrite),
            .ID_EX_MemtoReg(ID_EX_MemtoReg),
            
            .Zero(zero),
            
            .ID_EX_rd(ID_EX_rd),
            
            .ALU_Out(result),
            .MUX_ForwardB(data_out_c2),
            .PC_Adder(out1),
            
            .EX_MEM_Zero(EX_MEM_Zero),
            
            .EX_MEM_rd(EX_MEM_rd),
            
            .EX_MEM_MUX_ForwardB(EX_MEM_MUX_ForwardB),
            .EX_MEM_ALU_Out(EX_MEM_ALU_Out),
            .EX_MEM_PC_Adder(EX_MEM_PC_Adder),
            
            .EX_MEM_Branch(EX_MEM_Branch),
            .EX_MEM_MemRead(EX_MEM_MemRead),
            .EX_MEM_MemWrite(EX_MEM_MemWrite),
            .EX_MEM_RegWrite(EX_MEM_RegWrite),
            .EX_MEM_MemtoReg(EX_MEM_MemtoReg)
        );

    Data_Memory DMem(
            .Mem_Addr(EX_MEM_ALU_Out),
            .WriteData(ReadData2),
            .clk(clk),
            .MemWrite(EX_MEM_MemWrite), 
            .MemRead(EX_MEM_MemRead), 
            .Read_Data(Read_Data)
        );

    
    Adder add3(
            .a(64'd4),
            .b(PC_Out),
            .c(Adder1Out)
        );

    MUX muxMemory(
            .A(Adder1Out),
            .B(EX_MEM_PC_Adder),
            .O(PC_In),
            .S(EX_MEM_Branch & EX_MEM_Zero)
        );

    MEM_WB b4(
            .clk(clk),
            .reset(reset),
            .EX_MEM_RegWrite(EX_MEM_RegWrite),
            .EX_MEM_MemtoReg(EX_MEM_MemtoReg),
            .EX_MEM_rd(EX_MEM_rd),
            .EX_MEM_ALU_Out(EX_MEM_ALU_Out),
            .Read_Data(Read_Data),
            .MEM_WB_RegWrite(MEM_WB_RegWrite),
            .MEM_WB_MemtoReg(MEM_WB_MemtoReg),
            .MEM_WB_rd(MEM_WB_rd),
            .MEM_WB_ALU_Out(MEM_WB_ALU_Out),
            .MEM_WB_Read_Data(MEM_WB_Read_Data)
        );

    MUX a14(
            .A(MEM_WB_ALU_Out),
            .B(MEM_WB_Read_Data),
            .S(MEM_WB_MemtoReg),
            .O(MEM_WB_WriteData)
        );

endmodule
