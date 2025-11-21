library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types_pkg.all;

entity vga_controller is
    generic (
        H_RES : integer := 640;
        H_FP : integer := 16;
        H_SP : integer := 96;
        H_BP : integer := 48;
        V_RES : integer := 480;
        V_FP : integer := 10;
        V_SP : integer := 2;
        V_BP : integer := 33;
        
        GRID_W : integer := 80;
        GRID_H : integer := 60;
        P_SIZE : integer := 8
    );
port (
        clk_vga : in std_logic;
        rst : in std_logic;
        
        pixel_x_out : out std_logic_vector(9 downto 0);
        pixel_y_out : out std_logic_vector(9 downto 0);
        video_on_out : out std_logic;
        HS_out : out std_logic;
        VS_out : out std_logic;
        
        game_state_in : in std_logic_vector(2 downto 0);
        p1_x_in : in integer range 0 to GRID_W-1;
        p1_y_in : in integer range 0 to GRID_H-1;
        p2_x_in : in integer range 0 to GRID_W-1;
        p2_y_in : in integer range 0 to GRID_H-1;
        p1_trail_in : in std_logic;
        p2_trail_in : in std_logic;
        p1_score_in : in integer range 0 to 9;
        p2_score_in : in integer range 0 to 9;
        
        p1_dir_in: in T_Direction;
        p2_dir_in: in T_Direction;
        
        VGA_R_out : out std_logic_vector(3 downto 0);
        VGA_G_out : out std_logic_vector(3 downto 0);
        VGA_B_out : out std_logic_vector(3 downto 0)
    );
end entity vga_controller;

architecture Behavioral of vga_controller is

    -- fondo_rom
    component fondo_rom is
        generic(
            DATA_WIDTH : integer := 12;
            ADDR_WIDTH : integer := 19; 
            INIT_FILE  : string  := ""
        );
        port(
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- bike_rom
    component bike_rom is
        generic(
            DATA_WIDTH : integer := 12;
            ADDR_WIDTH : integer := 7;
            INIT_FILE  : string  := ""
        );
        port(
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- score_text_rom
    component score_text_rom is
        generic(
            DATA_WIDTH : integer := 12;
            ADDR_WIDTH : integer := 11;
            INIT_FILE  : string  := ""
        );
        port(
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- game_over_rom
    component game_over_rom is
        generic(
            DATA_WIDTH : integer := 12;
            ADDR_WIDTH : integer := 13;
            INIT_FILE  : string  := ""
        );
        port(
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;
    
    -- winner_rom
    component winner_rom is
        generic(
            DATA_WIDTH : integer := 12;
            ADDR_WIDTH : integer := 12;
            INIT_FILE  : string  := ""
        );
        port(
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- num_rom
    component num_rom is
        generic(
            DATA_WIDTH : integer := 12;
            ADDR_WIDTH : integer := 8; 
            INIT_FILE  : string  := ""
        );
        port(
            clock   : in  std_logic;
            address : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            q       : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- Timing
    constant H_TOTAL : integer := H_RES + H_FP + H_SP + H_BP;
    constant H_SYNC_START : integer := H_RES + H_FP;
    constant H_SYNC_END : integer := H_SYNC_START + H_SP;
    constant V_TOTAL : integer := V_RES + V_FP + V_SP + V_BP;
    constant V_SYNC_START : integer := V_RES + V_FP;
    constant V_SYNC_END : integer := V_SYNC_START + V_SP;

    signal h_count : integer range 0 to H_TOTAL-1;
    signal v_count : integer range 0 to V_TOTAL-1;
    signal video_on : std_logic;
    signal hs : std_logic;
    signal vs : std_logic;
    signal pixel_x : integer range 0 to H_RES;
    signal pixel_y : integer range 0 to V_RES;
    signal pixel_x_d : integer range 0 to H_RES;
    signal pixel_y_d : integer range 0 to V_RES;
    signal video_on_d : std_logic;
    signal grid_x : integer range 0 to GRID_W-1;
    signal grid_y : integer range 0 to GRID_H-1;
    
    -- Sprites
    constant SPRITE_W_H : integer := 12;
    constant SPRITE_H_H : integer := 8;
    constant SPRITE_W_V : integer := 8;
    constant SPRITE_H_V : integer := 12;
    signal p1_sprite_w, p1_sprite_h : integer;
    signal p2_sprite_w, p2_sprite_h : integer;

    -- Colores
    constant C_BLACK : std_logic_vector(11 downto 0) := "000000000000";
    constant C_P1_TRAIL : std_logic_vector(11 downto 0) := "100000000000";
    constant C_P2_TRAIL : std_logic_vector(11 downto 0) := "000000001000";
    constant C_TRANSPARENT : std_logic_vector(11 downto 0) := "101010101010"; -- x"AAA"
    constant C_FONDO_OSCURO : std_logic_vector(11 downto 0) := "000100010010";
    constant C_LINEA_GRILLA : std_logic_vector(11 downto 0) := "001100110100";
    constant C_BARRA_FONDO : std_logic_vector(11 downto 0) := "010001101000"; -- x"468"

    -- Señales de ROM de Sprites
    signal rgb_out : std_logic_vector(11 downto 0);
    signal rom_q_p1_up, rom_q_p1_down, rom_q_p1_left, rom_q_p1_right : std_logic_vector(11 downto 0);
    signal rom_q_p2_up, rom_q_p2_down, rom_q_p2_left, rom_q_p2_right : std_logic_vector(11 downto 0);
    signal rom_q_p1_up_d, rom_q_p1_down_d, rom_q_p1_left_d, rom_q_p1_right_d : std_logic_vector(11 downto 0);
    signal rom_q_p2_up_d, rom_q_p2_down_d, rom_q_p2_left_d, rom_q_p2_right_d : std_logic_vector(11 downto 0);
    
    
    --SEÑALES Y CONSTANTES PARA IMÁGENES DE BARRA
    constant SCORE_IMG_W : integer := 57; 
    constant SCORE_IMG_H : integer := 22; 
    constant SCORE_HEIGHT : integer := 30; 
    constant BARRA_Y_START : integer := 9;
    constant BARRA_Y_END   : integer := 9 + SCORE_HEIGHT;
    constant SCORE_Y_START : integer := 12; 
    constant SCORE_Y_END   : integer := 35; 
    constant SCORE1_X_START: integer := 24; 
    constant SCORE1_X_END  : integer := 80; 
    constant SCORE2_X_START: integer := 500;
    constant SCORE2_X_END  : integer := 556;
    
    -- Constantes y señales para TRON 
    constant TRON_IMG_W  : integer := 56;
    constant TRON_IMG_H  : integer := 23;
    constant TRON_X_START: integer := 292;
    constant TRON_X_END  : integer := 348; 
    signal x_rel_tron : integer range 0 to TRON_IMG_W-1;
    signal y_rel_tron : integer range 0 to TRON_IMG_H-1;
    signal rom_addr_tron_text : std_logic_vector(10 downto 0);
    signal rom_q_tron_text    : std_logic_vector(11 downto 0);
    
    -- Constantes y señales para SCORE
    signal x_rel_score : integer range 0 to SCORE_IMG_W-1;
    signal y_rel_score : integer range 0 to SCORE_IMG_H-1; 
    signal rom_addr_score_text : std_logic_vector(10 downto 0);
    signal rom_q_score_red   : std_logic_vector(11 downto 0);
    signal rom_q_score_blue  : std_logic_vector(11 downto 0);

    
    --CONSTANTES Y SEÑALES PARA NÚMEROS DE PUNTAJE
    constant NUM_IMG_W : integer := 11;
    constant NUM_IMG_H : integer := 18;
    constant NUM_Y_START : integer := SCORE_Y_START + 6;
    constant NUM_Y_END   : integer := NUM_Y_START + NUM_IMG_H; 
    constant NUM1_X_START: integer := SCORE1_X_END + 4; 
    constant NUM1_X_END  : integer := NUM1_X_START + NUM_IMG_W;
    constant NUM2_X_START: integer := SCORE2_X_END + 4; 
    constant NUM2_X_END  : integer := NUM2_X_START + NUM_IMG_W;
    signal x_rel_num : integer range 0 to NUM_IMG_W-1;
    signal y_rel_num : integer range 0 to NUM_IMG_H-1;
    signal rom_addr_num : std_logic_vector(7 downto 0); 
    signal rom_q_num_0, rom_q_num_1, rom_q_num_2, rom_q_num_3, rom_q_num_4 : std_logic_vector(11 downto 0);
    signal rom_q_num_5, rom_q_num_6, rom_q_num_7, rom_q_num_8, rom_q_num_9 : std_logic_vector(11 downto 0);
    signal p1_num_data_mux, p2_num_data_mux : std_logic_vector(11 downto 0);
    signal p1_num_data_d, p2_num_data_d : std_logic_vector(11 downto 0);

    
    -- Constantes y Señales de Game Over
    constant GO_IMG_W : integer := 100;
    constant GO_IMG_H : integer := 60;
    constant GO_X_START : integer := (H_RES - GO_IMG_W) / 2;
    constant GO_X_END   : integer := GO_X_START + GO_IMG_W;
    constant GO_Y_START : integer := (V_RES - GO_IMG_H) / 2;
    constant GO_Y_END   : integer := GO_Y_START + GO_IMG_H;
    constant WIN_IMG_W : integer := 70;
    constant WIN_IMG_H : integer := 30;
    constant WIN_X_START : integer := (H_RES - WIN_IMG_W) / 2;
    constant WIN_X_END   : integer := WIN_X_START + WIN_IMG_W;
    constant WIN_Y_START : integer := (V_RES - WIN_IMG_H) / 2;
    constant WIN_Y_END   : integer := WIN_Y_START + WIN_IMG_H;
    signal x_rel_go : integer range 0 to GO_IMG_W-1;
    signal y_rel_go : integer range 0 to GO_IMG_H-1;
    signal rom_addr_go : std_logic_vector(12 downto 0);
    signal rom_q_go    : std_logic_vector(11 downto 0);
    signal rom_q_go_d  : std_logic_vector(11 downto 0);
    signal x_rel_win : integer range 0 to WIN_IMG_W-1;
    signal y_rel_win : integer range 0 to WIN_IMG_H-1;
    signal rom_addr_win : std_logic_vector(11 downto 0);
    signal rom_q_red_win  : std_logic_vector(11 downto 0);
    signal rom_q_blue_win : std_logic_vector(11 downto 0);
    signal rom_q_red_win_d  : std_logic_vector(11 downto 0);
    signal rom_q_blue_win_d : std_logic_vector(11 downto 0);
    
    -- Otras señales
    signal rom_q_p1 : std_logic_vector(11 downto 0);
    signal rom_q_p2 : std_logic_vector(11 downto 0);
    signal is_p1_pixel : boolean;
    signal is_p2_pixel : boolean;
    signal rom_x_rel_p1 : integer range 0 to 11;
    signal rom_y_rel_p1 : integer range 0 to 11;
    signal rom_x_rel_p2 : integer range 0 to 11;
    signal rom_y_rel_p2 : integer range 0 to 11;
    signal rom_addr_p1 : std_logic_vector(6 downto 0);
    signal rom_addr_p2 : std_logic_vector(6 downto 0);
    signal VGA_R_reg : std_logic_vector(3 downto 0);
    signal VGA_G_reg : std_logic_vector(3 downto 0);
    signal VGA_B_reg : std_logic_vector(3 downto 0);

begin

    process(clk_vga, rst)
    begin
        if rst = '1' then
            h_count <= 0;
            v_count <= 0;
        elsif rising_edge(clk_vga) then
            if h_count < H_TOTAL-1 then
                h_count <= h_count + 1;
            else
                h_count <= 0;
                if v_count < V_TOTAL-1 then
                    v_count <= v_count + 1;
                else
                    v_count <= 0;
                end if;
            end if;
        end if;
    end process;
    hs <= '0' when (h_count >= H_SYNC_START and h_count < H_SYNC_END) else '1';
    vs <= '0' when (v_count >= V_SYNC_START and v_count < V_SYNC_END) else '1';
    video_on <= '1' when (h_count < H_RES and v_count < V_RES) else '0';
    HS_out <= hs;
    VS_out <= vs;
    video_on_out <= video_on;
    pixel_x_out <= std_logic_vector(to_unsigned(h_count, 10));
    pixel_y_out <= std_logic_vector(to_unsigned(v_count, 10));

    process(clk_vga, rst)
    begin
        if rst = '1' then
            pixel_x_d <= 0;
            pixel_y_d <= 0;
            video_on_d <= '0';
        elsif rising_edge(clk_vga) then
            pixel_x_d <= h_count;
            pixel_y_d <= v_count;
            video_on_d <= video_on;
            
            -- Registros de Sprites
            rom_q_p1_up_d    <= rom_q_p1_up;
            rom_q_p1_down_d  <= rom_q_p1_down;
            rom_q_p1_left_d  <= rom_q_p1_left;
            rom_q_p1_right_d <= rom_q_p1_right;
            rom_q_p2_up_d    <= rom_q_p2_up;
            rom_q_p2_down_d  <= rom_q_p2_down;
            rom_q_p2_left_d  <= rom_q_p2_left;
            rom_q_p2_right_d <= rom_q_p2_right;
            
            -- Registros de Game Over / Winner
            rom_q_go_d <= rom_q_go;
            rom_q_red_win_d <= rom_q_red_win;
            rom_q_blue_win_d <= rom_q_blue_win;
            
            -- Registros de Números de Puntaje
            p1_num_data_d <= p1_num_data_mux;
            p2_num_data_d <= p2_num_data_mux;
        end if;
    end process;

    -- Cálculos de Coordenadas
    pixel_x <= h_count;
    pixel_y <= v_count;
    grid_x <= pixel_x_d / P_SIZE;
    grid_y <= pixel_y_d / P_SIZE;
    rom_x_rel_p1 <= pixel_x - (p1_x_in * P_SIZE);
    rom_y_rel_p1 <= pixel_y - (p1_y_in * P_SIZE);
    rom_x_rel_p2 <= pixel_x - (p2_x_in * P_SIZE);
    rom_y_rel_p2 <= pixel_y - (p2_y_in * P_SIZE);
    process(p1_dir_in)
    begin
        case p1_dir_in is
            when UP | DOWN =>
                p1_sprite_w <= SPRITE_W_V; p1_sprite_h <= SPRITE_H_V;
            when LEFT | RIGHT =>
                p1_sprite_w <= SPRITE_W_H; p1_sprite_h <= SPRITE_H_H;
        end case;
    end process;
    process(p2_dir_in)
    begin
        case p2_dir_in is
            when UP | DOWN =>
                p2_sprite_w <= SPRITE_W_V; p2_sprite_h <= SPRITE_H_V;
            when LEFT | RIGHT =>
                p2_sprite_w <= SPRITE_W_H; p2_sprite_h <= SPRITE_H_H;
        end case;
    end process;
    rom_addr_p1 <= std_logic_vector(to_unsigned(rom_y_rel_p1 * p1_sprite_w + rom_x_rel_p1, 7));
    rom_addr_p2 <= std_logic_vector(to_unsigned(rom_y_rel_p2 * p2_sprite_w + rom_x_rel_p2, 7));
    
    -- Proceso de Cálculo de Dirección de Barra SCORE/TRON
    process(pixel_x, pixel_y)
    begin
        if (pixel_y >= SCORE_Y_START and pixel_y < SCORE_Y_END) then
            y_rel_score <= pixel_y - SCORE_Y_START;
            y_rel_tron  <= pixel_y - SCORE_Y_START; 
        else
            y_rel_score <= 0;
            y_rel_tron  <= 0;
        end if;
        
        if (pixel_x >= SCORE1_X_START and pixel_x < SCORE1_X_END) then
            x_rel_score <= pixel_x - SCORE1_X_START;
        elsif (pixel_x >= SCORE2_X_START and pixel_x < SCORE2_X_END) then
            x_rel_score <= pixel_x - SCORE2_X_START;
        else
            x_rel_score <= 0;
        end if;
        
        if (pixel_x >= TRON_X_START and pixel_x < TRON_X_END) then
            x_rel_tron <= pixel_x - TRON_X_START;
        else
            x_rel_tron <= 0;
        end if;
    end process;
    rom_addr_score_text <= std_logic_vector(to_unsigned((y_rel_score * SCORE_IMG_W) + x_rel_score, 11));
    rom_addr_tron_text <= std_logic_vector(to_unsigned((y_rel_tron * TRON_IMG_W) + x_rel_tron, 11)); -- Usa su propio ancho

    -- --- Cálculo de Dirección Game Over / Winner
    process(pixel_x, pixel_y)
    begin
        -- Cálculo Game Over
        if (pixel_y >= GO_Y_START and pixel_y < GO_Y_END) and
           (pixel_x >= GO_X_START and pixel_x < GO_X_END) then
            y_rel_go <= pixel_y - GO_Y_START;
            x_rel_go <= pixel_x - GO_X_START;
        else
            y_rel_go <= 0;
            x_rel_go <= 0;
        end if;
        
        -- Cálculo Winner
        if (pixel_y >= WIN_Y_START and pixel_y < WIN_Y_END) and
           (pixel_x >= WIN_X_START and pixel_x < WIN_X_END) then
            y_rel_win <= pixel_y - WIN_Y_START;
            x_rel_win <= pixel_x - WIN_X_START;
        else
            y_rel_win <= 0;
            x_rel_win <= 0;
        end if;
    end process;
    
    -- Asignación de direcciones para las nuevas ROMs
    rom_addr_go <= std_logic_vector(to_unsigned((y_rel_go * GO_IMG_W) + x_rel_go, 13));
    rom_addr_win <= std_logic_vector(to_unsigned((y_rel_win * WIN_IMG_W) + x_rel_win, 12));
    
    -- Cálculo de Dirección
    process(pixel_x, pixel_y)
    begin
        -- Cálculo de Y
        if (pixel_y >= NUM_Y_START and pixel_y < NUM_Y_END) then
            y_rel_num <= pixel_y - NUM_Y_START;
        else
            y_rel_num <= 0;
        end if;
        
        -- Cálculo de X
        if (pixel_x >= NUM1_X_START and pixel_x < NUM1_X_END) then
            x_rel_num <= pixel_x - NUM1_X_START;
        elsif (pixel_x >= NUM2_X_START and pixel_x < NUM2_X_END) then
            x_rel_num <= pixel_x - NUM2_X_START;
        else
            x_rel_num <= 0;
        end if;
    end process;
    
    -- Asignación de dirección común para todas las ROMs de números
    rom_addr_num <= std_logic_vector(to_unsigned((y_rel_num * NUM_IMG_W) + x_rel_num, 8));


    is_p1_pixel <= (pixel_x_d >= (p1_x_in * P_SIZE) AND pixel_x_d < (p1_x_in * P_SIZE) + p1_sprite_w) AND
                   (pixel_y_d >= (p1_y_in * P_SIZE) AND pixel_y_d < (p1_y_in * P_SIZE) + p1_sprite_h);
    is_p2_pixel <= (pixel_x_d >= (p2_x_in * P_SIZE) AND pixel_x_d < (p2_x_in * P_SIZE) + p2_sprite_w) AND
                   (pixel_y_d >= (p2_y_in * P_SIZE) AND pixel_y_d < (p2_y_in * P_SIZE) + p2_sprite_h);

    
    -- Instancias de ROM de Sprites
    ROM_P1_UP : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_red_up.mif")
        port map (clock => clk_vga, address => rom_addr_p1, q => rom_q_p1_up);
    ROM_P1_DOWN : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_red_down.mif")
        port map (clock => clk_vga, address => rom_addr_p1, q => rom_q_p1_down);
    ROM_P1_LEFT : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_red_left.mif")
        port map (clock => clk_vga, address => rom_addr_p1, q => rom_q_p1_left);
    ROM_P1_RIGHT : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_red_right.mif")
        port map (clock => clk_vga, address => rom_addr_p1, q => rom_q_p1_right);
    ROM_P2_UP : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_blue_up.mif")
        port map (clock => clk_vga, address => rom_addr_p2, q => rom_q_p2_up);
    ROM_P2_DOWN : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_blue_down.mif")
        port map (clock => clk_vga, address => rom_addr_p2, q => rom_q_p2_down);
    ROM_P2_LEFT : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_blue_left.mif")
        port map (clock => clk_vga, address => rom_addr_p2, q => rom_q_p2_left);
    ROM_P2_RIGHT : entity work.bike_rom
        generic map (DATA_WIDTH => 12, ADDR_WIDTH => 7, INIT_FILE => "tron_blue_right.mif")
        port map (clock => clk_vga, address => rom_addr_p2, q => rom_q_p2_right);

    -- Instancias de ROM de Barra
    ROM_SCORE_RED : entity work.score_text_rom
        generic map (
            DATA_WIDTH => 12,
            ADDR_WIDTH => 11, 
            INIT_FILE  => "score_text_red.mif"
        )
        port map (
            clock   => clk_vga,
            address => rom_addr_score_text,
            q       => rom_q_score_red
        );

    ROM_SCORE_BLUE : entity work.score_text_rom
        generic map (
            DATA_WIDTH => 12,
            ADDR_WIDTH => 11, 
            INIT_FILE  => "score_text_blue.mif"
        )
        port map (
            clock   => clk_vga,
            address => rom_addr_score_text,
            q       => rom_q_score_blue
        );

    ROM_TRON_TEXT : entity work.score_text_rom
        generic map (
            DATA_WIDTH => 12,
            ADDR_WIDTH => 11, 
            INIT_FILE  => "tron_text.mif" 
        )
        port map (
            clock   => clk_vga,
            address => rom_addr_tron_text,
            q       => rom_q_tron_text
        );
    
    --INSTANCIAS DE ROM Game Over / Winner
    ROM_IMG_GO : entity work.game_over_rom
        generic map (
            DATA_WIDTH => 12,
            ADDR_WIDTH => 13, 
            INIT_FILE  => "game_over.mif" 
        )
        port map (
            clock   => clk_vga,
            address => rom_addr_go,
            q       => rom_q_go
        );
        
    ROM_IMG_RED_WIN : entity work.winner_rom
        generic map (
            DATA_WIDTH => 12,
            ADDR_WIDTH => 12, 
            INIT_FILE  => "red_winner.mif" 
        )
        port map (
            clock   => clk_vga,
            address => rom_addr_win,
            q       => rom_q_red_win
        );
        
    ROM_IMG_BLUE_WIN : entity work.winner_rom
        generic map (
            DATA_WIDTH => 12,
            ADDR_WIDTH => 12, 
            INIT_FILE  => "blue_winner.mif"
        )
        port map (
            clock   => clk_vga,
            address => rom_addr_win,
            q       => rom_q_blue_win
        );
        
    -- Instancias de ROMs de Números (0-9)
    ROM_NUM_0 : entity work.num_rom
        generic map (INIT_FILE  => "0.mif") 
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_0);
        
    ROM_NUM_1 : entity work.num_rom
        generic map (INIT_FILE  => "1.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_1);

    ROM_NUM_2 : entity work.num_rom
        generic map (INIT_FILE  => "2.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_2);

    ROM_NUM_3 : entity work.num_rom
        generic map (INIT_FILE  => "3.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_3);

    ROM_NUM_4 : entity work.num_rom
        generic map (INIT_FILE  => "4.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_4);

    ROM_NUM_5 : entity work.num_rom
        generic map (INIT_FILE  => "5.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_5);

    ROM_NUM_6 : entity work.num_rom
        generic map (INIT_FILE  => "6.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_6);
        
    ROM_NUM_7 : entity work.num_rom
        generic map (INIT_FILE  => "7.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_7);
        
    ROM_NUM_8 : entity work.num_rom
        generic map (INIT_FILE  => "8.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_8);
        
    ROM_NUM_9 : entity work.num_rom
        generic map (INIT_FILE  => "9.mif")
        port map (clock => clk_vga, address => rom_addr_num, q => rom_q_num_9);

    
    -- MUX de Sprites
    process(p1_dir_in, rom_q_p1_up_d, rom_q_p1_down_d, rom_q_p1_left_d, rom_q_p1_right_d)
    begin
        case p1_dir_in is
            when UP    => rom_q_p1 <= rom_q_p1_up_d;
            when DOWN  => rom_q_p1 <= rom_q_p1_down_d;
            when LEFT  => rom_q_p1 <= rom_q_p1_left_d;
            when RIGHT => rom_q_p1 <= rom_q_p1_right_d;
        end case;
    end process;
    
    process(p2_dir_in, rom_q_p2_up_d, rom_q_p2_down_d, rom_q_p2_left_d, rom_q_p2_right_d)
    begin
        case p2_dir_in is
            when UP    => rom_q_p2 <= rom_q_p2_up_d;
            when DOWN  => rom_q_p2 <= rom_q_p2_down_d;
            when LEFT  => rom_q_p2 <= rom_q_p2_left_d;
            when RIGHT => rom_q_p2 <= rom_q_p2_right_d;
        end case;
    end process;
    
    -- MUXes para Números de Puntaje
    process(p1_score_in, rom_q_num_0, rom_q_num_1, rom_q_num_2, rom_q_num_3, rom_q_num_4, 
            rom_q_num_5, rom_q_num_6, rom_q_num_7, rom_q_num_8, rom_q_num_9)
    begin
        case p1_score_in is
            when 0 => p1_num_data_mux <= rom_q_num_0;
            when 1 => p1_num_data_mux <= rom_q_num_1;
            when 2 => p1_num_data_mux <= rom_q_num_2;
            when 3 => p1_num_data_mux <= rom_q_num_3;
            when 4 => p1_num_data_mux <= rom_q_num_4;
            when 5 => p1_num_data_mux <= rom_q_num_5;
            when 6 => p1_num_data_mux <= rom_q_num_6;
            when 7 => p1_num_data_mux <= rom_q_num_7;
            when 8 => p1_num_data_mux <= rom_q_num_8;
            when 9 => p1_num_data_mux <= rom_q_num_9;
            when others => p1_num_data_mux <= C_TRANSPARENT; 
        end case;
    end process;
    
    process(p2_score_in, rom_q_num_0, rom_q_num_1, rom_q_num_2, rom_q_num_3, rom_q_num_4, 
            rom_q_num_5, rom_q_num_6, rom_q_num_7, rom_q_num_8, rom_q_num_9)
    begin
        case p2_score_in is
            when 0 => p2_num_data_mux <= rom_q_num_0;
            when 1 => p2_num_data_mux <= rom_q_num_1;
            when 2 => p2_num_data_mux <= rom_q_num_2;
            when 3 => p2_num_data_mux <= rom_q_num_3;
            when 4 => p2_num_data_mux <= rom_q_num_4;
            when 5 => p2_num_data_mux <= rom_q_num_5;
            when 6 => p2_num_data_mux <= rom_q_num_6;
            when 7 => p2_num_data_mux <= rom_q_num_7;
            when 8 => p2_num_data_mux <= rom_q_num_8;
            when 9 => p2_num_data_mux <= rom_q_num_9;
            when others => p2_num_data_mux <= C_TRANSPARENT; -- Default
        end case;
    end process;

    -- coloreado
    process(video_on_d, pixel_x_d, pixel_y_d,
            game_state_in, p1_score_in, p2_score_in,
            is_p1_pixel, is_p2_pixel,
            rom_q_p1, rom_q_p2,
            p1_trail_in, p2_trail_in,
            rom_q_score_red, rom_q_score_blue, rom_q_tron_text,
            rom_q_go_d, rom_q_red_win_d, rom_q_blue_win_d,
            p1_num_data_d, p2_num_data_d)
    begin
        rgb_out <= C_BLACK;

        if video_on_d = '1' then
            
            case game_state_in is
            
                -- IMAGEN "GAME OVER" 
                when "110" =>
                    rgb_out <= C_BLACK; 
                    if (pixel_y_d >= GO_Y_START and pixel_y_d < GO_Y_END) and
                       (pixel_x_d >= GO_X_START and pixel_x_d < GO_X_END) then
                        
                        if rom_q_go_d /= C_TRANSPARENT then
                            rgb_out <= rom_q_go_d;
                        end if;
                    end if;

                -- IMAGEN "WINNER" 
                when "111" =>
                    rgb_out <= C_BLACK;
                    
                    -- LÓGICA DE GANADOR
                    if p2_score_in >= 5 then -- P2 (Azul) PIERDE
                        -- Dibujar imagen RED WINNER (P1 Gana)
                        if (pixel_y_d >= WIN_Y_START and pixel_y_d < WIN_Y_END) and
                           (pixel_x_d >= WIN_X_START and pixel_x_d < WIN_X_END) then
                            
                            if rom_q_red_win_d /= C_TRANSPARENT then
                                rgb_out <= rom_q_red_win_d;
                            end if;
                        end if;
                        
                    elsif p1_score_in >= 5 then -- P1 (Rojo) PIERDE
                        -- Dibujar imagen BLUE WINNER (P2 Gana)
                        if (pixel_y_d >= WIN_Y_START and pixel_y_d < WIN_Y_END) and
                           (pixel_x_d >= WIN_X_START and pixel_x_d < WIN_X_END) then
                            
                            if rom_q_blue_win_d /= C_TRANSPARENT then
                                rgb_out <= rom_q_blue_win_d;
                            end if;
                        end if;
                    else
                        -- Fallback (empate o error)
                        if (pixel_y_d >= GO_Y_START and pixel_y_d < GO_Y_END) and
                           (pixel_x_d >= GO_X_START and pixel_x_d < GO_X_END) then
                            if rom_q_go_d /= C_TRANSPARENT then
                                rgb_out <= rom_q_go_d;
                            end if;
                        end if;
                    end if;

               
                -- --- ESTADO DE "JUEGO CONGELADO" (CHOQUE / PAUSA) ---
                when "100" =>
                    
                    -- Borde Negro
                    if (pixel_x_d < 14) or (pixel_x_d >= H_RES - 20) or
                       (pixel_y_d < 6) or (pixel_y_d >= V_RES - 20) then
                        rgb_out <= C_BLACK;
                    else
                        -- Fondo Oscuro
                        rgb_out <= C_FONDO_OSCURO;
                        
                        -- Fondo de Barra
                        if (pixel_y_d >= BARRA_Y_START and pixel_y_d < BARRA_Y_END) then
                             rgb_out <= C_BARRA_FONDO; 
                        end if;
                        
                        -- Grilla
                        if (pixel_y_d >= BARRA_Y_END) and ((pixel_x_d mod 8 = 7) or (pixel_y_d mod 8 = 7)) then
                            rgb_out <= C_LINEA_GRILLA;
                        end if;

                        -- Dibujar "SCORE" y "TRON" (Y=12 a 35)
                        if (pixel_y_d >= SCORE_Y_START and pixel_y_d < SCORE_Y_END) then
                            
                            -- Ventana SCORE (Izquierda)
                            if (pixel_x_d >= SCORE1_X_START and pixel_x_d < SCORE1_X_END) then
                                if rom_q_score_red /= C_TRANSPARENT then
                                    rgb_out <= rom_q_score_red;
                                end if;
                            -- Ventana SCORE (Derecha)
                            elsif (pixel_x_d >= SCORE2_X_START and pixel_x_d < SCORE2_X_END) then
                                if rom_q_score_blue /= C_TRANSPARENT then
                                    rgb_out <= rom_q_score_blue;
                                end if;
                            -- Ventana TRON (Centro)
                            elsif (pixel_x_d >= TRON_X_START and pixel_x_d < TRON_X_END) then
                                if rom_q_tron_text /= C_TRANSPARENT then
                                    rgb_out <= rom_q_tron_text;
                                end if;
                            end if;
                        end if;
                        
                        -- 6. Dibujar los NÚMEROS (Y=18 a 29)
                        if (pixel_y_d >= NUM_Y_START and pixel_y_d < NUM_Y_END) then
                            
                            -- Ventana Número P1
                            if (pixel_x_d >= NUM1_X_START and pixel_x_d < NUM1_X_END) then
                                if p1_num_data_d /= C_TRANSPARENT then
                                    rgb_out <= p1_num_data_d;
                                end if;
                            -- Ventana Número P2
                            elsif (pixel_x_d >= NUM2_X_START and pixel_x_d < NUM2_X_END) then
                                if p2_num_data_d /= C_TRANSPARENT then
                                    rgb_out <= p2_num_data_d;
                                end if;
                            end if;
                        end if;
                        
                        -- 7. Dibujar Estelas
                        if (p2_trail_in = '1') then rgb_out <= C_P2_TRAIL; end if;
                        if (p1_trail_in = '1') then rgb_out <= C_P1_TRAIL; end if;

                        -- 8. Dibujar Motos
                        if (is_p2_pixel) then
                            if rom_q_p2 /= C_TRANSPARENT then rgb_out <= rom_q_p2; end if;
                        end if;
                        if (is_p1_pixel) then
                            if rom_q_p1 /= C_TRANSPARENT then rgb_out <= rom_q_p1; end if;
                        end if;
                    end if;

                -- ESTADO DE JUEGO
                when others =>
                    
                    if (pixel_x_d < 14) or (pixel_x_d >= H_RES - 20) or
                       (pixel_y_d < 6) or (pixel_y_d >= V_RES - 20) then
                        rgb_out <= C_BLACK;
                    else
                        rgb_out <= C_FONDO_OSCURO;
                        if (pixel_y_d >= BARRA_Y_START and pixel_y_d < BARRA_Y_END) then
                             rgb_out <= C_BARRA_FONDO; 
                        end if;
                        if (pixel_y_d >= BARRA_Y_END) and ((pixel_x_d mod 8 = 7) or (pixel_y_d mod 8 = 7)) then
                            rgb_out <= C_LINEA_GRILLA;
                        end if;

                        -- 5. Dibujar "SCORE" y "TRON" (Y=12 a 35)
                        if (pixel_y_d >= SCORE_Y_START and pixel_y_d < SCORE_Y_END) then
                            -- Ventana SCORE (Izquierda)
                            if (pixel_x_d >= SCORE1_X_START and pixel_x_d < SCORE1_X_END) then
                                if rom_q_score_red /= C_TRANSPARENT then
                                    rgb_out <= rom_q_score_red;
                                end if;
                            -- Ventana SCORE (Derecha)
                            elsif (pixel_x_d >= SCORE2_X_START and pixel_x_d < SCORE2_X_END) then
                                if rom_q_score_blue /= C_TRANSPARENT then
                                    rgb_out <= rom_q_score_blue;
                                end if;
                            -- Ventana TRON (Centro)
                            elsif (pixel_x_d >= TRON_X_START and pixel_x_d < TRON_X_END) then
                                if rom_q_tron_text /= C_TRANSPARENT then
                                    rgb_out <= rom_q_tron_text;
                                end if;
                            end if;
                        end if;
                        
                        -- Dibujar los NÚMEROS (Y=18 a 29)
                        if (pixel_y_d >= NUM_Y_START and pixel_y_d < NUM_Y_END) then
                            if (pixel_x_d >= NUM1_X_START and pixel_x_d < NUM1_X_END) then
                                if p1_num_data_d /= C_TRANSPARENT then
                                    rgb_out <= p1_num_data_d;
                                end if;
                            elsif (pixel_x_d >= NUM2_X_START and pixel_x_d < NUM2_X_END) then
                                if p2_num_data_d /= C_TRANSPARENT then
                                    rgb_out <= p2_num_data_d;
                                end if;
                            end if;
                        end if;
                        
                        -- Estelas
                        if (p2_trail_in = '1') then rgb_out <= C_P2_TRAIL; end if;
                        if (p1_trail_in = '1') then rgb_out <= C_P1_TRAIL; end if;
                        
                        -- Motos
                        if (is_p2_pixel) then
                            if rom_q_p2 /= C_TRANSPARENT then rgb_out <= rom_q_p2; end if;
                        end if;
                        if (is_p1_pixel) then
                            if rom_q_p1 /= C_TRANSPARENT then rgb_out <= rom_q_p1; end if;
                        end if;
                    end if;
            
            end case;
            
        end if;
        
    end process;
    
    -- Salidas de Color
    process(clk_vga)
    begin
        if rising_edge(clk_vga) then
            VGA_R_reg <= rgb_out(11 downto 8);
            VGA_G_reg <= rgb_out(7 downto 4);
            VGA_B_reg <= rgb_out(3 downto 0);
        end if;
    end process;
    
    VGA_R_out <= VGA_R_reg;
    VGA_G_out <= VGA_G_reg;
    VGA_B_out <= VGA_B_reg;

end Behavioral;