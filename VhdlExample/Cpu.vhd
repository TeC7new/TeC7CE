-- Cpu.vhd
-- 情報電子工学総合実験(CE1)用 TeC の CPU 部分 !!! 模範解答 !!!
--
-- (c)2014 - 2019 by Dept. of Computer Science and Electronic Engineering,
--            Tokuyama College of Technology, JAPAN

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Cpu is
  Port ( Clk     : in  std_logic;
         -- 制御
         Reset   : in  std_logic;
         Intr    : in  std_logic;
         Stop    : in  std_logic;
         Halt    : out std_logic;
         Err     : out std_logic;
         Ir      : out std_logic;
         Mr      : out std_logic;
         Li      : out std_logic;                       -- 命令フェッチ
         -- RAM
         Addr    : out std_logic_vector (7 downto 0);
         Din     : in  std_logic_vector (7 downto 0);
         Dout    : out std_logic_vector (7 downto 0);
         We      : out std_logic;
         -- Console
         DbgAin  : in  std_logic_vector (2 downto 0);
         DbgDin  : in  std_logic_vector (7 downto 0);
         DbgDout : out std_logic_vector (7 downto 0);
         DbgWe   : in  std_logic;
         Flags   : out std_logic_vector (2 downto 0)    -- CSZ
         );
end Cpu;

architecture Behavioral of Cpu is
  component Sequencer is
    Port ( Clk   : in  STD_LOGIC;
           -- 入力
           Reset : in  STD_LOGIC;
           OP    : in  STD_LOGIC_vector (3 downto 0);
           Rd    : in  STD_LOGIC_vector (1 downto 0);
           Rx    : in  STD_LOGIC_vector (1 downto 0);
           FlagE : in  STD_LOGIC;   -- E
           FlagC : in  STD_LOGIC;   -- C
           FlagS : in  STD_LOGIC;   -- S
           FlagZ : in  STD_LOGIC;   -- Z
           Intr  : in  STD_LOGIC;
           Stop  : in  STD_LOGIC;
           -- CPU内部の制御用に出力
           IrLd  : out  STD_LOGIC;
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
           Ma    : out  STD_LOGIC_vector (1 downto 0);
           Md    : out  STD_LOGIC_vector (1 downto 0);
           Ir    : out  STD_LOGIC;
           Mr    : out  STD_LOGIC;
           -- CPU外部へ出力
           Err   : out  STD_LOGIC;
           We    : out  STD_LOGIC;
           Halt  : out  STD_LOGIC
           );
  end component;

-- CPU Register
  signal G0    : std_logic_vector(7 downto 0);
  signal G1    : std_logic_vector(7 downto 0);
  signal G2    : std_logic_vector(7 downto 0);
  signal SP    : std_logic_vector(7 downto 0);

-- PSW
  signal PC   : std_logic_vector(7 downto 0);
  signal FlgE : std_logic;            -- E
  signal FlgC : std_logic;            -- C
  signal FlgS : std_logic;            -- S
  signal FlgZ : std_logic;            -- Z

-- IR
  signal OP    : std_logic_vector(3 downto 0);
  signal Rd    : std_logic_vector(1 downto 0);
  signal Rx    : std_logic_vector(1 downto 0);
  
-- DR
  signal DR    : std_logic_vector(7 downto 0);

-- 内部バス
  signal EA    : std_logic_vector(7 downto 0); -- Effective Address
  signal RegRd : std_logic_vector(7 downto 0); -- Reg[Rd]
  signal RegRx : std_logic_vector(7 downto 0); -- Reg[Rx]
  signal Alu   : std_logic_vector(8 downto 0); -- ALU出力（キャリー付)
  signal Zero  : std_logic;                    -- ALUが0か？
  signal SftRd : std_logic_vector(8 downto 0); -- RegRdをシフトしたもの

-- 内部制御線（ステートマシンの出力)
  signal IrLd  : std_logic;                    -- IR:Ld
  signal DrLd  : std_logic;                    -- DR:Ld
  signal FlgLdA: std_logic;                    -- Flag:LdA 
  signal FlgLdM: std_logic;                    -- Flag:LdM
  signal FlgOn : std_logic;                    -- Flag:On
  signal FlgOff: std_logic;                    -- Flag:Off
  signal GrLd  : std_logic;                    -- GR:Ld
  signal SpM1  : std_logic;                    -- SP:M1
  signal SpP1  : std_logic;                    -- SP:P1
  signal PcP1  : std_logic;                    -- PC:P1
  signal PcJmp : std_logic;                    -- PC:JMP
  signal PcRet : std_logic;                    -- PC:RET

  signal Ma    : std_logic_vector(1 downto 0); -- MA(PC=00,EA=01,SP=10)
  signal Md    : std_logic_vector(1 downto 0); -- MD(PC=0,FLAG=,GR=1)

  signal Io    : std_logic;                    --IO

begin
-- コンソールへの接続
  Flags <= FlgC & FlgS & FlgZ;
  Li    <= IrLd;

-- 制御部
  seq1: Sequencer Port map (Clk, Reset, OP, Rd, Rx, FlgE, FlgC, FlgS, FlgZ, Intr,
                            Stop, IrLd, DrLd, FlgLdA, FlgLdM, FlgOn, FlgOff, GrLd, SpM1, SpP1,
                            PcP1, PcJmp, PcRet, Ma, Md, Ir, Mr, Err, We, Halt);

-- BUS
  Addr <= PC when Ma="00" else
          EA when Ma="01" else SP;
  
  Ea <= DR + RegRx;

  Dout <= PC when Md="00" else
          (FlgE & FlgC & FlgS & FlgZ) when Md="01" else RegRd;
  
-- ALU
  SftRd <= (RegRd & '0') when Rx(1)='0' else                      -- SHLA/SHLL
    (RegRd(0) & RegRd(7) & RegRd(7 downto 1)) when Rx(0)='0' else -- SHRA
    (RegRd(0) & '0' & RegRd(7 downto 1));                         -- SHRL
  
  Alu <= ('0' & RegRd) + ('0' & DR) when OP="0011" else           -- Add
         ('0' & RegRd) - ('0' & DR) when OP="0100" or OP="0101" else --Sub/Cmp
         ('0' & RegRd)and('0' & DR) when OP="0110" else           -- And
         ('0' & RegRd)or ('0' & DR) when OP="0111" else           -- Or
         ('0' & RegRd)xor('0' & DR) when OP="1000" else           -- Xor
         SftRd when OP="1001" else ('0' & DR);                    -- Shift

  Zero <= '1' when ALU(7 downto 0)="00000000" else '0';

-- IR の制御
  process(Clk)
  begin
    if (Clk'event and Clk='1') then
      if (IrLd='1') then
        OP <= Din(7 downto 4);
        Rd <= Din(3 downto 2);
        Rx <= Din(1 downto 0);
      end if;
    end if;
  end process;

  -- DR の制御
  process(Clk)
  begin
    if (DrLd='1') then
        DR <= Din;
    end if;
  end process;
  
-- PC の制御
  process(Clk, Reset)
  begin
    if (Reset='1') then
      PC <= "00000000";
    elsif (Clk'event and Clk='1') then
      if (PcJmp='1') then
        PC <= Ea;
      elsif (PcRet='1') then
        PC <= Din;
      elsif (PcP1='1') then
        PC <= PC + 1;
      elsif (DbgWe='1' and DbgAin="100") then                 --コンソールからの書き込み
        PC <= DbgDin;
      end if;
    end if;
  end process;
  
-- CPU レジスタの制御
  RegRd <= G0 when Rd="00" else G1 when Rd="01" else
           G2 when Rd="10" else SP;

  RegRx <= G1 when Rx="01" else G2 when Rx="10" else "00000000";
  
  process(Clk, Reset)
  begin
    if (Reset='1') then
      G0  <= "00000000";
      G1  <= "00000000";
      G2  <= "00000000";
      SP  <= "00000000";
    elsif (Clk'event and Clk='1') then
      if (GrLd='1') then
        case Rd is
          when "00" => G0 <= Alu(7 downto 0);
          when "01" => G1 <= Alu(7 downto 0);
          when "10" => G2 <= Alu(7 downto 0);
          when others => SP <= Alu(7 downto 0);
        end case;
      elsif (SpP1='1') then
        SP <= SP + 1;
      elsif (SpM1='1') then
        SP <= Sp - 1;
      elsif (DbgWe='1') then                                  --コンソールからの書き込み
        case DbgAin is
          when "000" => G0 <= DbgDin;
          when "001" => G1 <= DbgDin;
          when "010" => G2 <= DbgDin;
          when "011" => SP <= DbgDin;
          when others => null;
        end case;
      end if;
    end if;
  end process;

-- フラグの制御
  process(Clk, Reset)
  begin
    if (Reset='1') then
      FlgE <= '0';
      FlgC <= '0';
      FlgS <= '0';
      FlgZ <= '0';
    elsif (Clk'event and Clk='1') then
      if (FlgLdA='1') then
        FlgC <= Alu(8);                -- Carry
        FlgS <= Alu(7);                -- Sign
        FlgZ <= Zero;                  -- Zero
      elsif (FlgLdM='1') then
        FlgE <= Din(7);                -- Enable
        FlgC <= Din(2);                -- Carry
        FlgS <= Din(1);                -- Sign
        FlgZ <= Din(0);                -- Zero
      elsif (FlgOn='1') then
        FlgE <= '1';                   -- Enable
      elsif (FlgOff='1') then
        FlgE <= '0';                   -- Enable
      end if;
    end if;
  end process;
  
-- デバッグ用のコンソール接続
  DbgDout <= G0 when DbgAin="000" else
             G1 when DbgAin="001" else
             G2 when DbgAin="010" else
             SP when DbgAin="011" else
             PC;

end Behavioral;

