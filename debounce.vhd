library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
    port (
        clk_in  : in  std_logic; -- 50MHz
        rst     : in  std_logic; -- Reset activo-alto
        btn_in  : in  std_logic;
        btn_out : out std_logic
    );
end entity debounce;

architecture Behavioral of debounce is

    constant DEBOUNCE_LIMIT : integer := 500000;
    signal counter : integer range 0 to DEBOUNCE_LIMIT;
    signal stable_level : std_logic;
    signal debounced_level : std_logic;
begin

    process(clk_in, rst)
    begin
        if rst = '1' then
            counter <= 0;
            stable_level <= '0';
            debounced_level <= '0';
        elsif rising_edge(clk_in) then 
            if btn_in /= stable_level then
                -- Reiniciar contador
                counter <= 0;
                stable_level <= btn_in;
            elsif counter < DEBOUNCE_LIMIT then
                -- Esperando que se estabilice
                counter <= counter + 1;
            else
                debounced_level <= stable_level;
            end if;
        end if;
    end process;
    
    btn_out <= debounced_level;
    
end Behavioral;