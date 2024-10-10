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
  
  NxtSt <= STAT00 when (State{0}='1' and Stop='1') or    -- Stop
                       State{3}='1' or State{4}='1' or   -- LD/.../XOR/SHxx,ST
                       State{5}='1' or State{7}='1' or   -- JMP,IN
                       State{8}='1' or State{10}='1' or  -- OUT,CALL
                       State{11}='1' or State{13}='1' or -- EI/DI,PUSH
                       State{15}='1' or State{16}='1' or -- POP,RET
                       State{18}='1' or State{19}='1' or -- RETI,HALT
                       State{20}='1' else                -- ERROR
           STAT01 when State{0}='1' and Stop='0'  else   -- Fetch
           STAT02 when DecSt(1)='1' and Type1='1' else   -- LD/ADD/.../XOR
           "0011" when (DecSt(1)='1' and OP="1001") or   -- SHIFT
                       DecSt(2)='1' else                 -- LD/ADD/.../XOR
           "0100" when DecSt(1)='1' and OP="0010" else   -- ST
           "0101" when DecSt(1)='1' and OP="1010" else   -- JMP/JZ/JC/JM
           "0110" when DecSt(1)='1' and OP="1011" else   -- CALL
           "0111" when DecSt(6)='1'               else
           "1000" when DecSt(1)='1' and OP="1101" and Rx="00" else -- PUSH
           "1001" when DecSt(8)='1'               else
           "1010" when DecSt(1)='1' and OP="1101" and Rx="10" else -- POP
           "1011" when DecSt(10)='1'                          else
           "1100" when DecSt(1)='1' and OP="1110" else   -- RET
           "1101";                                       -- HALT/ERROR

  process(Clk, Reset)
  begin
    if (Reset='1') then
      Stat <= "0000";
    elsif (Clk'event and Clk='1') then
      Stat <= NxtSt;
    end if;
  end process;
  
  -- Control Signals
  Jmp  <= '1' when Rd="00" else '0';  -- JMP
  Jz   <= '1' when Rd="01" else '0';  -- JZ
  Jc   <= '1' when Rd="10" else '0';  -- JC
  Jm   <= '1' when Rd="11" else '0';  -- JM
  Immd <= '1' when Rx="11" else '0';  -- Immediate mode
  
  --        JMP     JZ and Z Flag       JC and C Flag       JM and S Flag
  JmpCnd <= Jmp or (Jz and Flag(0)) or (Jc and Flag(2)) or (Jm and Flag(1));
  
  IrLd  <= DecSt(0);
  DrLd  <= DecSt(1) or (DecSt(2) and not Immd) or DecSt(10);
  FlgLd <= '1' when DecSt(3)='1' and OP/="0001" else '0';    -- OP /=LD
  GrLd  <= '1' when (DecSt(3)='1' and OP/="0101") or         -- OP /=CMP
           DecSt(11)='1' else '0';
  SpP1  <= DecSt(10) or DecSt(12);
  SpM1  <= DecSt(6)  or DecSt(8);
  PcP1  <= (DecSt(0) and not Stop) or
           DecSt(2) or DecSt(4) or DecSt(5) or DecSt(6);
  PcJmp <= (DecSt(5) and JmpCnd) or DecSt(7);
  PcRet <= DecSt(12);
  Ma    <= "00" when DecSt(0)='1' or DecSt(1)='1' else       -- "00"=PC
           "01" when DecSt(2)='1' or DecSt(4)='1' else       -- "01"=EA
           "10";                                             -- "10"=SP
  Md    <= not DecSt(7);
  We    <= DecSt(4)  or DecSt(7) or DecSt(9);
  Halt  <= DecSt(13);

end Behavioral;
