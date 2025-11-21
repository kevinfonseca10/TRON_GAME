library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity menu_rom is
    generic(
        DATA_WIDTH : integer := 12;  -- 12 bits de color (RGB 444)
        ADDR_WIDTH : integer := 11;  -- 2^11 = 2048 (Suficiente para tus imágenes de 1288 píxeles)
        INIT_FILE  : string  := ""   -- Nombre del archivo .mif
    );
    port(
        clock   : in  std_logic;
        address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity menu_rom;

architecture Behavioral of menu_rom is
    -- Definimos la memoria
    type rom_t is array(0 to (2**ADDR_WIDTH)-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Inicialización INIT_FILE
    signal rom : rom_t;
    attribute ram_init_file : string;
    attribute ram_init_file of rom : signal is INIT_FILE;

    signal addr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);
begin

    process(clock)
    begin
        if rising_edge(clock) then
            addr_reg <= address;
        end if;
    end process;
    
    q <= rom(to_integer(unsigned(addr_reg)));

end Behavioral;