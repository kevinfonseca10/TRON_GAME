library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity game_over_rom is
    generic(
        DATA_WIDTH : integer := 12;
        ADDR_WIDTH : integer := 13; -- 2^13 = 8192 (suficiente para 6000)
        INIT_FILE  : string  := ""
    );
    port(
        clock   : in  std_logic;
        address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity game_over_rom;

architecture Behavioral of game_over_rom is
    
    constant ROM_DEPTH : integer := 2**ADDR_WIDTH;
    type T_ROM is array(0 to ROM_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal rom : T_ROM;
    attribute ram_init_file : string;
    attribute ram_init_file of rom : signal is INIT_FILE;

    signal q_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
begin

    process(clock)
    begin
        if rising_edge(clock) then
            q_reg <= rom(to_integer(unsigned(address)));
        end if;
    end process;
    
    q <= q_reg;

end Behavioral;