library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game_ram is
    generic (
        ADDR_WIDTH : integer := 13;
        DATA_WIDTH : integer := 1
    );
    port (
        -- PA Escritura
        clk_a     : in  std_logic; 
        we_a      : in  std_logic;
        addr_a    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        data_in_a : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        
        -- PB Lectura
        clk_b     : in  std_logic;
        addr_b    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        data_out_b: out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity game_ram;

architecture Behavioral of game_ram is
    
    constant RAM_DEPTH : integer := 2**ADDR_WIDTH;
    type ram_type is array (0 to RAM_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal mem : ram_type := (others => (others => '0'));

begin

    -- PA Escritura
    process(clk_a)
    begin
        if rising_edge(clk_a) then
            if we_a = '1' then
                mem(to_integer(unsigned(addr_a))) <= data_in_a;
            end if;
        end if;
    end process;
    
    -- PB Lectura
    process(clk_b)
    begin
        if rising_edge(clk_b) then
            data_out_b <= mem(to_integer(unsigned(addr_b)));
        end if;
    end process;

end Behavioral;