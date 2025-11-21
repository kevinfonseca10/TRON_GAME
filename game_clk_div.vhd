library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game_clk_div is
    generic (
        DIVISOR : integer := 5000000 -- 50MHz / 5M = 10 Hz
    );
    port (
        clk_in  : in  std_logic;
        rst     : in  std_logic;
        clk_out : out std_logic
    );
end entity game_clk_div;

architecture Behavioral of game_clk_div is
    signal counter : integer range 0 to DIVISOR-1;
    signal clk_pulse : std_logic;
begin

    process(clk_in, rst)
    begin
        if rst = '1' then
            counter <= 0;
            clk_pulse <= '0';
        elsif rising_edge(clk_in) then
            clk_pulse <= '0';
            if counter = DIVISOR-1 then
                counter <= 0;
                clk_pulse <= '1'; -- Pulso de 1 ciclo
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

    clk_out <= clk_pulse; -- Salida es un pulso

end Behavioral;