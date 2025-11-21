library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

-- ----------------------------------------------------------------
-- ENTIDAD: tron_rom
-- ----------------------------------------------------------------
entity tron_rom is
    generic (
        MIF_FILE : string := "" 
    );
    port (
        clock   : in std_logic;
        -- ¡ARREGLO! 7 bits de dirección (para 8x12 = 96 píxeles)
        address : in std_logic_vector(6 downto 0); 
        q       : out std_logic_vector(11 downto 0)
    );
end entity tron_rom;

-- ----------------------------------------------------------------
-- ARQUITECTURA: Behavioral
-- ----------------------------------------------------------------
architecture Behavioral of tron_rom is

    component altsyncram
        generic (
            init_file         : string;
            operation_mode    : string;
            width_a           : natural;
            widthad_a         : natural;
            outdata_reg_a     : string
        );
        port (
            clock0    : in std_logic;
            address_a : in std_logic_vector(widthad_a-1 downto 0);
            q_a       : out std_logic_vector(width_a-1 downto 0)
        );
    end component altsyncram;
    
    signal sub_wire0 : std_logic_vector(11 downto 0);

begin

    rom_instance : altsyncram
        generic map (
            init_file         => MIF_FILE,
            operation_mode    => "ROM",
            width_a           => 12,        -- 12 bits de color (RGB 4:4:4)
            widthad_a         => 7,         -- ¡ARREGLO! 7 bits de dirección
            outdata_reg_a     => "CLOCK0"   
        )
        port map (
            clock0    => clock,
            address_a => address,
            q_a       => sub_wire0
        );

    q <= sub_wire0;

end architecture Behavioral;