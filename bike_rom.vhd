library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bike_rom is
    generic(
        DATA_WIDTH : integer := 12;             -- Color RGB 4:4:4
        ADDR_WIDTH : integer := 7;              
        INIT_FILE  : string := "sprite.mif"     -- archivo MIF
    );
    port(
        clock  : in  std_logic;
        address: in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        q      : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture Behavioral of bike_rom is

    type rom_t is array(0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal rom : rom_t;

    attribute ram_init_file : string;
    attribute ram_init_file of rom : signal is INIT_FILE;

begin
    process(clock)
    begin
        if rising_edge(clock) then
            q <= rom(to_integer(unsigned(address)));
        end if;
    end process;

end Behavioral;