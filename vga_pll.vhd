library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Genera 25MHz (c0) y 50MHz (c1) desde 50MHz (inclk0)
entity VGA_PLL is
    port (
        inclk0 : in  std_logic := '0';
        areset : in  std_logic := '0';
        c0     : out std_logic;
        c1     : out std_logic
    );
end entity VGA_PLL;

architecture Behavioral of VGA_PLL is
    signal clk_25_reg : std_logic := '0';
begin
    -- Salida c1 (50 MHz)
    c1 <= inclk0;

    -- Salida c0 (25 MHz)
    process(inclk0, areset)
    begin
        if areset = '1' then
            clk_25_reg <= '0';
        elsif rising_edge(inclk0) then
            clk_25_reg <= not clk_25_reg;
        end if;
    end process;
    c0 <= clk_25_reg;
end architecture Behavioral;