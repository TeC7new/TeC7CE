-- Sequencer.vhd
-- 情報電子工学総合実験(CE1)用 TeC CPU の制御部
--
-- (c)2014 - 2019 by Dept. of Computer Science and Electronic Engineering,
--            Tokuyama College of Technology, JAPAN

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Sequencer is
  Port ( Clk   : in  STD_LOGIC;
         -- 入力
         Reset : in  STD_LOGIC;
         OP    : in  STD_LOGIC_VECTOR (3 downto 0);
         Rd    : in  STD_LOGIC_VECTOR (1 downto 0);
         Rx    : in  STD_LOGIC_VECTOR (1 downto 0);
         FlagE : in  STD_LOGIC;
         FlagC : in  STD_LOGIC;
         FlagS : in  STD_LOGIC;
         FlagZ : in  STD_LOGIC;
         Stop  : in  STD_LOGIC;
         Intr  : in  STD_LOGIC;
         -- CPU内部の制御用に出力
         LiLd  : out  STD_LOGIC;
         DrLd  : out  STD_LOGIC;
         FlgLdA: out  STD_LOGIC;
         FlgLdM: out  STD_LOGIC;
         FlgOn : out  STD_LOGIC;
         FlgOff: out  STD_LOGIC;
         GrLd  : out  STD_LOGIC;
         SpM1  : out  STD_LOGIC;
         SpP1  : out  STD_LOGIC;
         PcP1  : out  STD_LOGIC;
         PcJmp : out  STD_LOGIC;
         PcRet : out  STD_LOGIC;
         Ma    : out  STD_LOGIC_VECTOR (1 downto 0);
         Md    : out  STD_LOGIC_VECTOR (1 downto 0);
         -- CPU外部へ出力
         IR    : out  STD_LOGIC;
         MR    : out  STD_LOGIC;
         Err   : out  STD_LOGIC;
         We    : out  STD_LOGIC;
         Halt  : out  STD_LOGIC
         );
end Sequencer;

architecture Behavioral of Sequencer is

subtype stat is STD_LOGIC_VECTOR(25 downto 0);
constant STAT00 : stat := "00000000000000000000000001";
constant STAT01 : stat := "00000000000000000000000010";
constant STAT02 : stat := "00000000000000000000000100";
constant STAT03 : stat := "00000000000000000000001000";
constant STAT04 : stat := "00000000000000000000010000";
constant STAT05 : stat := "00000000000000000000100000";
constant STAT06 : stat := "00000000000000000001000000";
constant STAT07 : stat := "00000000000000000010000000";
constant STAT08 : stat := "00000000000000000100000000";
constant STAT09 : stat := "00000000000000001000000000";
constant STAT10 : stat := "00000000000000010000000000";
constant STAT11 : stat := "00000000000000100000000000";
constant STAT12 : stat := "00000000000001000000000000";
constant STAT13 : stat := "00000000000010000000000000";
constant STAT14 : stat := "00000000000100000000000000";
constant STAT15 : stat := "00000000001000000000000000";
constant STAT16 : stat := "00000000010000000000000000";
constant STAT17 : stat := "00000000100000000000000000";
constant STAT18 : stat := "00000001000000000000000000";
constant STAT19 : stat := "00000010000000000000000000";
constant STAT20 : stat := "00000100000000000000000000";
constant STAT21 : stat := "00001000000000000000000000";
constant STAT22 : stat := "00010000000000000000000000";
constant STAT23 : stat := "00100000000000000000000000";
constant STAT24 : stat := "01000000000000000000000000";
constant STAT25 : stat := "10000000000000000000000000";

  signal State : stat; -- State
  signal NxtSt : stat; -- Next State
  signal DROM  : stat;

  signal Jmp   : STD_LOGIC;                     -- JMP
  signal Jz    : STD_LOGIC;                     -- JZ
  signal Jc    : STD_LOGIC;                     -- JC
  signal Jm    : STD_LOGIC;                     -- JM
  singal Jnz   : STD_LOGIC;                     -- JNZ
  signal Jnc   : STD_LOGIC;                     -- JNC
  signal Jnm   : STD_LOGIC;                     -- JNM
  signal JmpCnd: STD_LOGIC;                     -- Jmp Condition
  signal Immd  : STD_LOGIC;                     -- Immediate mode
  signal Cmp   : STD_LOGIC;                     -- CMP
  signal Ld    : STD_LOGIC;                     -- LD

begin
-- State machine
  
  NxtSt <=  DROM   when State(1)='1' else
            STAT00 when (State(0)='1' and Stop='1') or   -- Stop
                       State(3)='1' or State(4)='1' or   -- LD/.../XOR/SHxx,ST
                       State(5)='1' or State(7)='1' or   -- JMP,IN
                       State(8)='1' or State(10)='1' or  -- OUT,CALL
                       State(11)='1' or State(13)='1' or -- EI/DI,PUSH
                       State(15)='1' or State(16)='1' or -- POP,RET
                       State(18)='1' or State(19)='1' or -- RETI,HALT
                       State(20)='1' or                  -- ERROR
                       State(25)='1' else                -- Intr               
           STAT21 when State(0)='1' and Intr='1' and FlagE='1' else -- Stop
           STAT22 when State(21)='1' else                -- Intr
           STAT23 when State(22)='1' else                -- Intr
           STAT24 when State(23)='1' else                -- Intr
           STAT25 when State(24)='1' else                -- Intr
           STAT01 when State(0)='1' and Stop='0'  else   -- Fetch
           STAT03 when State(2)='1' else                 -- LD/ADD/.../XOR
           STAT07 when State(6)='1'               else   --IN
           STAT10 when State(9)='1' else                 --CALL
           STAT13 when State(12)='1' else                --PUSH
           STAT15 when State(14)='1' else                --POP
           STAT18 when State(17)='1'                     --RETI
           ;                                       

  process(Clk, Reset)
  begin
    if (Reset='1') then
      State <= STAT00;
    elsif (Clk'event and Clk='1') then
      State <= NxtSt;
    end if;
  end process;
  
  -- Control Signals
  Jmp  <= '1' when Rd="00" else '0';  -- JMP
  Jz   <= '1' when OP(0)='0' and Rd="01" else '0';  -- JZ
  Jc   <= '1' when OP(0)='0' and Rd="10" else '0';  -- JC
  Jm   <= '1' when OP(0)='0' and Rd="11" else '0';  -- JM
  Jnz  <= '1' when OP(0)='1' and Rd="01" else '0';  -- JNZ
  Jnc  <= '1' when OP(0)='1' and Rd="10" else '0';  -- JNC
  Jnm  <= '1' when OP(0)='1' and Rd="11" else '0';  -- JNM
  Immd <= '1' when Rx="11" else '0';  -- Immediate mode
  
  --        JMP     JZ and Z Flag       JC and C Flag       JM and S Flag
  JmpCnd <= Jmp or (Jz and FlagZ) or (Jc and FlagC) or (Jm and FlagS) or 
            (Jnz and not FlagZ) or (Jnc and not FlagC) or (Jnm and not FlagS);
  
  IrLd  <= State(0);                                         -- Stop
  DrLd  <= State(1) or                                       -- Fetch
           (State(2) and not Immd) or                        -- LD/ADD/.../XOR
           State(6) or State(14);                            -- IN, POP
  FlgLdA <= '1' when State(3)='1' and OP/="0001" else '0';   -- OP /=LD
  FlgLdM <= State(17);                                       -- RETI
  GrLd  <= '1' when (State(3)='1' and OP/="0101") or         -- OP /=CMP
           State(7)='1' or                                   -- IN
           State(15)='1' else '0';                           -- POP
  SpP1  <= State(14) or State(16) or State(17);              -- POP, RET, RETI
  SpM1  <= State(9)  or State(12) or                         -- CALL, PUSH
           Stete(21) or State(23);                           -- Intr
  PcP1  <= (State(0) and not Stop) or                        -- Stop
           State(2) or                                       -- LD/ADD/.../XOR
           State(4) or (State(5) and not JmpCnd) or          -- ST, JMP
           State(6) or State(8) or State(9);                 -- IN, OUT, CALL
  PcJmp <= (State(5) and JmpCnd) or State(10);               -- JMP, CALL
  PcRet <= State(16) or State(18) or                         -- RET, RETI
           State(24) or State(25);                           -- Intr
  Ma    <= "00" when State(0)='1' or State(1)='1' or
                     State(25)='1' else                      -- "00"=PC
           "01" when State(2)='1' or State(4) or 
                     State(6)='1' else                       -- "01"=EA
           "10";                                             -- "10"=SP
  Md    <= "00" when State(10)='1' or State(22)='1' else     -- "00"=PC
           "01" when State(23)='1' else                      -- "01"=FLAG
           "10";                                             -- "10"=GR
  We    <= State(4)  or State(8) or                          -- ST, OUT
           State(10) or State(13) or                         -- CALL, PUSH
           State(22) or State(23);                           -- Intr
  Halt  <= State(19) or State(20);                           -- HALT, ERROR
  Err   <= State(20);                                        -- ERROR

end Behavioral;
