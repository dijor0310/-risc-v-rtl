library ieee;
use ieee.numeric_std.all;

library work;
use work.cpu_defs_pack.all;
use work.bit_vector_natural_pack.all;

entity core is 
    port(
        CLK : in bit;
        RST : in bit;

        D_IN : in DataType;
        OP : out OpType6;
        D_OUT : out DataType;

        -- memory interface
        MEM_I_ready : in bit;
        MEM_O_cmd : out bit;
        MEM_O_we : out bit;

        MEM_O_byteEnable : out bit_vector(1 downto 0);
        MEM_O_addr : out DataType;
        MEM_O_data : out DataType;
        MEM_I_data : in DataType;
        MEM_I_dataReady : in bit;

        
        ALU_Wait : in bit;
        ALU_MultiCy : in bit;
        OUT_STATE : out bit_vector(6 downto 0)
    );
end core;

architecture Behav of core is 
    -- TODO PC_UNIT
    component pc_unit
        port (
            I_clk : in  bit;
            I_nPC : in  DataType;
            I_nPCop : in PcuOpType;
            O_PC : out DataType
        );
    end component;

    component controller
        port (
            CLK : in bit;
            RST : in bit;
    
            D_IN : in DataType;
            OP : out OpType6;
            D_OUT : out DataType;
    
            ALU_Wait : in bit;
            ALU_MultiCy : in bit;
            OUT_STATE : out bit_vector(6 downto 0)
            );
    end component;

    component ID
        port (
            I_CLK : in bit;
            I_EN : in bit;
            I_DATAINST : in InstrType;    -- Instruction to be decoded
            O_SELRS1 : out RegAddrType;   -- Selection out for regrs1
            O_SELRS2 : out RegAddrType    -- Selection out for regrs2
            O_SELD : out RegAddrType;     -- Selection out for regD
            O_DATAIMM : out DataType;     -- Immediate value out
            O_REGDWE : out bit;                        -- RegD wrtite enable
            O_ALUOP : out OpType6;        -- ALU opcode
            O_ALUFUNC : out FuncType;    -- ALU function
            O_MEMOP : out bit_vector(4 downto 0);      -- Memory operation 
            O_MULTYCYALU : out bit;                    -- is this a multi-cycle alu op?    
        );
    end component;

    component alu is
        port (
            op: in optype4;
            a: in datatype;
            b: in datatype;
            result: out datatype;
            f3: in func3type;
            f7: in func7type    
        );
    end component;

    component register_file
        port (
            CLK: in bit;
            ENABLE: in bit;
            W_ENABLE: in bit;
            D_IN: in DataType;
            SEL_RS1: in RegAddrType;
            SEL_RS2: in RegAddrType;
            SEL_RD: in RegAddrType;
            Q_OUT_A: out DataType;
            Q_OUT_B: out DataType);
            );
    end component;

    component mem_controller
        port (
            CLK : in bit;
            RST : in bit;
            OUT_READY : out bit;
            EXECUTE : in bit;
            W_ENABLE : in bit;
            ADDR : in AddrType;
            IN_DATA : in DataType;
            SIGN_EXTEND : in bit;
            OUT_DATA : out DataType;
            OUT_DATA_READY : out bit;
    
            MEM_I_ready : in bit;
            MEM_O_cmd : out bit;
            MEM_O_we : out bit;
            MEM_O_byteEnable : bit_vector (1 downto 0);
            MEM_O_addr : out DataType;
            MEM_O_data : out DataType;
            MEM_I_data : in DataType;
            MEM_I_dataReady : in bit);
    end component;

    signal state: bit_vector(6 downto 0) := (others => '0');
    signal pcop: bit_vector(1 downto 0);
    signal in_pc: AddrType;
    signal PC : AddrType := (others => '0');

    signal aluFunc: bit_vector(15 downto 0);
    signal memOp: OpType4;
    signal branchTarget: AddrType := (others => '0');
    signal instruction: DataType := (others => '0');
    signal data: DataType := (others => '0');
    signal dataDwe: bit := '0';
    signal Op: Optype6 := (others => '0');
    signal dataIMM : DataType := (others => '0');
    signal SEL_RS1 : RegAddrType := (others => '0');
    signal SEL_RS2 : RegAddrType := (others => '0');
    signal SEL_D : RegAddrType := (others => '0');
    
    signal memctl_ready : bit;
    signal memctl_execute : bit := '0';
    signal memctl_dataWe : bit;
    signal memctl_address : AddrType;
    signal memctl_in_data : DataType;
    signal memctl_dataByteEn : bit_vector(1 downto 0);
    signal memctl_out_data : DataType := (others => '0');
    signal memctl_dataReady : bit := '0';
    signal memctl_size : bit_vector(1 downto 0);
    signal memctl_signExtend : bit := '0';

    signal core_clock : bit := '0';

    signal reg_en : bit := '0';
    signal reg_we : bit := '0';

    signal reg_write_data : DataType := (others => '0');
    signal dataA : DataType := (others => '0');
    signal dataB : DataType := (others => '0');

    signal SEL_RS1 : RegAddrType := (others => '0');
    signal SEL_RS2 : RegAddrType := (others => '0');
    signal SEL_D : RegAddrType := (others => '0');

    signal op : Optype6 := (others => '0');
    signal aluFunc : bit_vector(15 downto 0); -- all funcs

    signal alu_output: DataType := (others => '0');
begin
    core_clock <= CLK;

    mem_controller_instance : mem_controller port map(
        CLK => CLK,
        RST => RST,
        OUT_READY => memctl_ready,
        EXECUTE => memctl_execute,
        W_ENABLE => memctl_dataWe
        ADDR => memctl_address,
        IN_DATA => memctl_in_data,
        SIGN_EXTEND => memctl_signExtend,
        OUT_DATA => memctl_out_data,
        OUT_DATA_READY => memctl_dataReady

        MEM_I_ready => MEM_I_ready, 
        MEM_O_cmd => MEM_O_cmd,
        MEM_O_we => MEM_O_we,
        MEM_O_byteEnable => MEM_O_byteEnable,
        MEM_O_addr => MEM_O_addr,
        MEM_O_data => MEM_O_data,
        MEM_I_data => MEM_I_data,
        MEM_I_dataReady => MEM_I_dataReady
    );

    pc_unit_instance : pc_unit port map(
        I_clk => core_clock, 
        I_nPC => in_pc,
        I_nPCop => pcop,
        O_PC => PC
    );

    controller_instance : controller port map(
        CLK => core_clock,
        RST => RST,
        --D_IN => 
        OP => op,
        --D_OUT => 
        ALU_Wait => ALU_WAIT,
        ALU_MultiCy => ALU_MULTI_CYCLE,
        OUT_STATE => state
    );

    decoder_instance : ID port map(

    
    );

    alu_instance : alu port map(
        op => aluop(6 downto 2),
        a => dataA,
        b => dataB,
        result => alu_output,
        f3 => aluFunc(2 downto 0),
        f7 => aluFunc(9 downto 3)
    );

    register_file_instance : register_file port map(
        CLK => core_clock,
        ENABLE => reg_en,
        W_ENABLE => reg_we,
        D_IN => reg_write_data,
        SEL_RS1 => SEL_RS1,
        SEL_RS2 => SEL_RS2,
        SEL_RD => SEL_RD,
        Q_OUT_A => dataA,
        Q_OUT_B => dataB
    );

end Behav;