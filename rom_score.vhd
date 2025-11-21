library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity score_rom is
    generic(
        DATA_WIDTH : integer := 12;
        ADDR_WIDTH : integer := 15;
        INIT_FILE  : string  := ""
    );
    port(
        clock   : in  std_logic;
        address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity score_rom;

architecture Behavioral of score_rom is

    type rom_t is array(0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal rom : rom_t;
    attribute ram_init_file : string;
    attribute ram_init_file of rom : signal is INIT_FILE;

    -- Señal para registrar la dirección
    signal addr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin
    -- Registrar la dirección de entrada
    process(clock)
    begin
        if rising_edge(clock) then
            addr_reg <= address;
        end if;
    end process;
    
    -- Lectura Combinacional
  
    q <= rom(to_integer(unsigned(addr_reg)));

end Behavioral;