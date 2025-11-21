library IEEE;

use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;



entity tron_top is

    Port (

        CLOCK_50 : in  std_logic;

        KEY      : in  std_logic_vector(0 downto 0);

        SW       : in  std_logic_vector(9 downto 0);

        

        VGA_R  : out std_logic_vector(7 downto 4);

        VGA_G  : out std_logic_vector(7 downto 4);

        VGA_B  : out std_logic_vector(7 downto 4);

        VGA_HS : out std_logic;

        VGA_VS : out std_logic;



        HEX0_out : out std_logic_vector(6 downto 0);

        HEX2_out : out std_logic_vector(6 downto 0)

    );

end entity tron_top;



architecture Behavioral of tron_top is


    -- CONSTANTES

    constant RAM_ADDR_BITS : integer := 13;

    constant GRID_WIDTH    : integer := 80;

    constant GRID_HEIGHT   : integer := 60;

    constant RAM_CLEAR_COUNT : integer := (GRID_WIDTH * GRID_HEIGHT) - 1;

    

    -- Dimensiones MIF

    constant LOGO_W : integer := 56;

    constant LOGO_H : integer := 23;

    constant NUM_W  : integer := 11;

    constant NUM_H  : integer := 18;


    -- Estados del Sistema

    type t_sys_state is (S_MENU, S_GAME);

    signal current_sys_state : t_sys_state := S_MENU;

    

    signal menu_selection : std_logic := '0'; -- 0=1P, 1=2P

    signal cpu_active_sig : std_logic := '0';

    -- Almacena la selección del menú

    signal final_cpu_active : std_logic := '0';



    -- Gráficos Menú

    signal int_x, int_y : integer range 0 to 1023;

    signal vga_r_menu, vga_g_menu, vga_b_menu : std_logic_vector(3 downto 0);

    

    -- Señales ROMs

    signal logo_addr : std_logic_vector(10 downto 0);

    signal logo_q    : std_logic_vector(11 downto 0);

    signal num1_addr : std_logic_vector(7 downto 0);

    signal num1_q    : std_logic_vector(11 downto 0);

    signal num2_addr : std_logic_vector(7 downto 0);

    signal num2_q    : std_logic_vector(11 downto 0);



    -- Señales Internas

    signal rst_active_high : std_logic;

    signal clk_vga, clk_50m_pll, clk_game_pulse : std_logic;

    

    signal db_p1_up, db_p1_down, db_p1_left, db_p1_right, db_start : std_logic;

    signal db_p2_up, db_p2_down, db_p2_left, db_p2_right : std_logic;



    signal lfsr_rnd_out : STD_LOGIC_VECTOR(7 downto 0);

    signal w_cpu_up, w_cpu_down, w_cpu_left, w_cpu_right : std_logic;

    signal final_p2_up, final_p2_down, final_p2_left, final_p2_right : std_logic;



    signal p1_dir_sig, p2_dir_sig : T_Direction;

    signal p1_x, p1_y, p2_x, p2_y : integer range 0 to GRID_WIDTH-1;

    signal p1_score, p2_score : integer range 0 to 9;

    signal game_state : std_logic_vector(2 downto 0);

    signal s_p1_score_vec, s_p2_score_vec : std_logic_vector(3 downto 0);

    

    -- Señales de RAM y Lógica de Limpieza

    signal s_ram_p1_we_logic, s_ram_p2_we_logic : std_logic;

    signal s_ram_p1_addr_logic, s_ram_p2_addr_logic : std_logic_vector(RAM_ADDR_BITS-1 downto 0);

    signal s_ram_p1_data_logic, s_ram_p2_data_logic : std_logic;

    

    signal s_ram_clear_start, s_ram_clear_done : std_logic;

    signal s_is_clearing_reg : std_logic := '0';

    signal s_clear_addr_reg  : integer range 0 to RAM_CLEAR_COUNT;

    

    signal s_ram_p1_we_final, s_ram_p2_we_final : std_logic;

    signal s_ram_p1_addr_final, s_ram_p2_addr_final : std_logic_vector(RAM_ADDR_BITS-1 downto 0);

    signal s_ram_p1_data_final, s_ram_p2_data_final : std_logic_vector(0 downto 0);

    

    signal ram_p1_data_out, ram_p2_data_out : std_logic_vector(0 downto 0);

    signal ram_check_addr : std_logic_vector(RAM_ADDR_BITS-1 downto 0);

    signal ram_check_data_p1, ram_check_data_p2 : std_logic;

    

    signal vga_ram_addr : std_logic_vector(RAM_ADDR_BITS-1 downto 0);

    signal ram_read_addr_p1, ram_read_addr_p2 : std_logic_vector(RAM_ADDR_BITS-1 downto 0);

    

    signal vga_r_game, vga_g_game, vga_b_game : std_logic_vector(3 downto 0);

    signal pixel_x, pixel_y : std_logic_vector(9 downto 0);

    signal video_on_sig : std_logic;


    -- COMPONENTES

    component VGA_PLL is port (inclk0 : in std_logic; areset : in std_logic; c0 : out std_logic; c1 : out std_logic); end component;

    component debounce is port (clk_in : in std_logic; rst : in std_logic; btn_in : in std_logic; btn_out : out std_logic); end component;

    component game_clk_div is generic (DIVISOR : integer := 5000000); port (clk_in : in std_logic; rst : in std_logic; clk_out : out std_logic); end component;

    

    component game_ram is generic (ADDR_WIDTH : integer := 13; DATA_WIDTH : integer := 1);

        port (clk_a : in std_logic; we_a : in std_logic; addr_a : in std_logic_vector(RAM_ADDR_BITS-1 downto 0);

              data_in_a : in std_logic_vector(DATA_WIDTH-1 downto 0); clk_b : in std_logic; addr_b : in std_logic_vector(RAM_ADDR_BITS-1 downto 0);

              data_out_b: out std_logic_vector(DATA_WIDTH-1 downto 0));

    end component;



    -- Game logic Puertos de limpieza y direccion

    component game_logic is

        generic (GRID_W : integer := 80; GRID_H : integer := 60; MAX_SCORE : integer := 5; RAM_ADDR_W : integer := 13);

        port (clk_game : in std_logic; rst : in std_logic; btn_start : in std_logic;

              btn_p1_up : in std_logic; btn_p1_down: in std_logic; btn_p1_left: in std_logic; btn_p1_right: in std_logic;

              btn_p2_up : in std_logic; btn_p2_down: in std_logic; btn_p2_left: in std_logic; btn_p2_right: in std_logic;

              collision_data_p1_in : in std_logic; collision_data_p2_in : in std_logic;

              ram_p1_we_out : out std_logic; ram_p1_addr_out : out std_logic_vector(RAM_ADDR_W-1 downto 0); ram_p1_data_out : out std_logic;

              ram_p2_we_out : out std_logic; ram_p2_addr_out : out std_logic_vector(RAM_ADDR_W-1 downto 0); ram_p2_data_out : out std_logic;

              ram_check_addr_out : out std_logic_vector(RAM_ADDR_W-1 downto 0);

              

              ram_clear_out : out std_logic;

              ram_clear_done_in : in std_logic;

              

              game_state_out : out std_logic_vector(2 downto 0); p1_x_out : out integer range 0 to GRID_W-1; p1_y_out : out integer range 0 to GRID_H-1;

              p2_x_out : out integer range 0 to GRID_W-1; p2_y_out : out integer range 0 to GRID_H-1;

              p1_dir_out : out T_Direction; p2_dir_out : out T_Direction;

              p1_score_out : out integer range 0 to 9; p2_score_out : out integer range 0 to 9);

    end component;



    -- vga_controller con puertos de dirección

    component vga_controller is

        generic (GRID_W : integer := 80; GRID_H : integer := 60; P_SIZE : integer := 8);

        port (clk_vga : in std_logic; rst : in std_logic; pixel_x_out : out std_logic_vector(9 downto 0); pixel_y_out : out std_logic_vector(9 downto 0);

              video_on_out : out std_logic; HS_out : out std_logic; VS_out : out std_logic; game_state_in : in std_logic_vector(2 downto 0);

              p1_x_in : in integer range 0 to GRID_W-1; p1_y_in : in integer range 0 to GRID_H-1;

              p2_x_in : in integer range 0 to GRID_W-1; p2_y_in : in integer range 0 to GRID_H-1;

              p1_trail_in : in std_logic; p2_trail_in : in std_logic; p1_score_in : in integer range 0 to 9; p2_score_in : in integer range 0 to 9;

              

              p1_dir_in: in T_Direction;

              p2_dir_in: in T_Direction;

              

              VGA_R_out : out std_logic_vector(3 downto 0);

              VGA_G_out : out std_logic_vector(3 downto 0); VGA_B_out : out std_logic_vector(3 downto 0));

    end component;



    component bin_to_sseg is Port ( bin : in STD_LOGIC_VECTOR(3 DOWNTO 0); sseg : out STD_LOGIC_VECTOR(6 DOWNTO 0)); end component;

    component lfsr_gen is port (clk : in STD_LOGIC; rst : in STD_LOGIC; rnd : out STD_LOGIC_VECTOR(7 downto 0)); end component;

    

    component contra_maquina is

        port (clk_50 : in std_logic; rst : in std_logic; enable_cpu : in std_logic; rnd_in : in std_logic_vector(7 downto 0);

              cpu_btn_up : out std_logic; cpu_btn_down : out std_logic; cpu_btn_left : out std_logic; cpu_btn_right : out std_logic);

    end component;



    component menu_rom is

        generic(DATA_WIDTH : integer := 12; ADDR_WIDTH : integer := 11; INIT_FILE : string := "");

        port(clock : in std_logic; address : in std_logic_vector(ADDR_WIDTH-1 downto 0); q : out std_logic_vector(DATA_WIDTH-1 downto 0));

    end component;



begin


    rst_active_high <= not KEY(0);


    -- Relojes, Inputs, Random


    PLL_inst : entity work.VGA_PLL

        port map(inclk0 => CLOCK_50, areset => '0', c0 => clk_vga, c1 => clk_50m_pll);

    

    Game_Clock_inst : entity work.game_clk_div

        generic map (DIVISOR => 5000000)

        port map (clk_in => clk_50m_pll, rst => rst_active_high, clk_out => clk_game_pulse);

    

    inst_DB_P1_UP    : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(0), btn_out => db_p1_up);

    inst_DB_P1_DOWN  : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(1), btn_out => db_p1_down);

    inst_DB_P1_LEFT  : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(2), btn_out => db_p1_left);

    inst_DB_P1_RIGHT : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(3), btn_out => db_p1_right);

    inst_DB_START    : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(4), btn_out => db_start);

    inst_DB_P2_UP    : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(5), btn_out => db_p2_up);

    inst_DB_P2_DOWN  : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(6), btn_out => db_p2_down);

    inst_DB_P2_LEFT  : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(7), btn_out => db_p2_left);

    inst_DB_P2_RIGHT : entity work.debounce port map(clk_in => clk_50m_pll, rst => rst_active_high, btn_in => SW(8), btn_out => db_p2_right);

    

    inst_LFSR : entity work.lfsr_gen

        port map (clk => CLOCK_50, rst => rst_active_high, rnd => lfsr_rnd_out);


    --MÁQUINA DE ESTADOS DEL MENÚ (Lógica corregida para selección de CPU

    process(clk_50m_pll, rst_active_high)

    begin

        if rst_active_high = '1' then

            current_sys_state <= S_MENU;

            menu_selection <= '0';

            final_cpu_active <= '0';

        elsif rising_edge(clk_50m_pll) then

            case current_sys_state is

                when S_MENU =>

                    -- Permite selección con botones de P1 y P2

                    if (db_p1_up='1' or db_p1_down='1' or db_p1_left='1' or db_p1_right='1' or

                        db_p2_up='1' or db_p2_down='1') then

                        menu_selection <= not menu_selection;

                    end if;

                    if db_start = '1' then

                        current_sys_state <= S_GAME;

                        -- Guarda la selección actual del menú antes de empezar

                        final_cpu_active <= menu_selection;

                    end if;

                when S_GAME =>

                    -- Transición de vuelta al menú cuando el juego está en S_IDLE ("000")

                    if game_state = "000" then

                        current_sys_state <= S_MENU;

                    end if;

            end case;

        end if;

    end process;

    

    -- Activamos la CPU si estamos en el juego 

    cpu_active_sig <= '1' when current_sys_state = S_GAME and final_cpu_active = '0' else '0';

    

    -- 3. JUEGO Y LÓGICA

    inst_Contra_Maquina : entity work.contra_maquina

        port map (

            clk_50 => CLOCK_50, rst => rst_active_high, enable_cpu => cpu_active_sig,

            rnd_in => lfsr_rnd_out,

            cpu_btn_up => w_cpu_up, cpu_btn_down => w_cpu_down, cpu_btn_left => w_cpu_left, cpu_btn_right => w_cpu_right

        );



    -- El jugador 2 (Azul) es controlado por la CPU solo si cpu_active_sig es '1'

    final_p2_up    <= w_cpu_up    when cpu_active_sig = '1' else db_p2_up;

    final_p2_down  <= w_cpu_down  when cpu_active_sig = '1' else db_p2_down;

    final_p2_left  <= w_cpu_left  when cpu_active_sig = '1' else db_p2_left;

    final_p2_right <= w_cpu_right when cpu_active_sig = '1' else db_p2_right;



    Game_Logic_inst : entity work.game_logic

        generic map (GRID_W => GRID_WIDTH, GRID_H => GRID_HEIGHT, MAX_SCORE => 5, RAM_ADDR_W => RAM_ADDR_BITS)

        port map (

            clk_game => clk_game_pulse, rst => rst_active_high, btn_start => db_start,

            btn_p1_up => db_p1_up, btn_p1_down=> db_p1_down, btn_p1_left=> db_p1_left, btn_p1_right=> db_p1_right,

            btn_p2_up => final_p2_up, btn_p2_down=> final_p2_down, btn_p2_left=> final_p2_left, btn_p2_right=> final_p2_right,

            collision_data_p1_in => ram_check_data_p1, collision_data_p2_in => ram_check_data_p2,

            ram_p1_we_out => s_ram_p1_we_logic, ram_p1_addr_out => s_ram_p1_addr_logic, ram_p1_data_out => s_ram_p1_data_logic,

            ram_p2_we_out => s_ram_p2_we_logic, ram_p2_addr_out => s_ram_p2_addr_logic, ram_p2_data_out => s_ram_p2_data_logic,

            ram_check_addr_out => ram_check_addr,

            

            -- PUERTOS CONECTADOS

            ram_clear_out => s_ram_clear_start,

            ram_clear_done_in => s_ram_clear_done,

            

            game_state_out => game_state,

            p1_x_out => p1_x, p1_y_out => p1_y, p2_x_out => p2_x, p2_y_out => p2_y,

            p1_dir_out => p1_dir_sig, p2_dir_out => p2_dir_sig,

            p1_score_out => p1_score, p2_score_out => p2_score

        );



    -- LÓGICA DE LIMPIEZA RAM

    process(clk_vga, rst_active_high)

    begin

        if rst_active_high = '1' then

            s_clear_addr_reg <= 0; s_is_clearing_reg <= '0'; s_ram_clear_done <= '0';

        elsif rising_edge(clk_vga) then

            if s_ram_clear_start = '1' then

                if s_is_clearing_reg = '0' and s_ram_clear_done = '0' then

                    s_is_clearing_reg <= '1'; s_clear_addr_reg <= 0;

                elsif s_is_clearing_reg = '1' then

                    if s_clear_addr_reg = RAM_CLEAR_COUNT then

                        s_is_clearing_reg <= '0'; s_ram_clear_done <= '1';

                    else

                        s_clear_addr_reg <= s_clear_addr_reg + 1;

                    end if;

                end if;

            else

                s_ram_clear_done <= '0';

            end if;

        end if;

    end process;

    

    s_ram_p1_we_final <= '1' when s_is_clearing_reg = '1' else s_ram_p1_we_logic;

    s_ram_p1_addr_final <= std_logic_vector(to_unsigned(s_clear_addr_reg, RAM_ADDR_BITS)) when s_is_clearing_reg = '1' else s_ram_p1_addr_logic;

    s_ram_p1_data_final(0) <= '0' when s_is_clearing_reg = '1' else s_ram_p1_data_logic;

    s_ram_p2_we_final <= '1' when s_is_clearing_reg = '1' else s_ram_p2_we_logic;

    s_ram_p2_addr_final <= std_logic_vector(to_unsigned(s_clear_addr_reg, RAM_ADDR_BITS)) when s_is_clearing_reg = '1' else s_ram_p2_addr_logic;

    s_ram_p2_data_final(0) <= '0' when s_is_clearing_reg = '1' else s_ram_p2_data_logic;



    vga_ram_addr <= std_logic_vector(to_unsigned(((to_integer(unsigned(pixel_y)) / 8) * GRID_WIDTH) + (to_integer(unsigned(pixel_x)) / 8), RAM_ADDR_BITS));

    ram_read_addr_p1 <= vga_ram_addr when video_on_sig = '1' else ram_check_addr;

    ram_read_addr_p2 <= vga_ram_addr when video_on_sig = '1' else ram_check_addr;



    RAM_P1 : entity work.game_ram

        generic map (ADDR_WIDTH => RAM_ADDR_BITS, DATA_WIDTH => 1)

        port map (clk_a => clk_vga, we_a => s_ram_p1_we_final, addr_a => s_ram_p1_addr_final, data_in_a => s_ram_p1_data_final,

                  clk_b => clk_vga, addr_b => ram_read_addr_p1, data_out_b=> ram_p1_data_out);

    RAM_P2 : entity work.game_ram

        generic map (ADDR_WIDTH => RAM_ADDR_BITS, DATA_WIDTH => 1)

        port map (clk_a => clk_vga, we_a => s_ram_p2_we_final, addr_a => s_ram_p2_addr_final, data_in_a => s_ram_p2_data_final,

                  clk_b => clk_vga, addr_b => ram_read_addr_p2, data_out_b=> ram_p2_data_out);

        

    process(clk_vga, rst_active_high)

    begin

        if rst_active_high = '1' then

            ram_check_data_p1 <= '0'; ram_check_data_p2 <= '0';

        elsif rising_edge(clk_vga) then

            if video_on_sig = '0' then

                ram_check_data_p1 <= ram_p1_data_out(0);

                ram_check_data_p2 <= ram_p2_data_out(0);

            end if;

        end if;

    end process;



    -- CONTROLADOR VGA

    VGA_Control_inst : entity work.vga_controller

        generic map (GRID_W => GRID_WIDTH, GRID_H => GRID_HEIGHT, P_SIZE => 8)

        port map (

            clk_vga => clk_vga, rst => rst_active_high,

            pixel_x_out => pixel_x, pixel_y_out => pixel_y, video_on_out=> video_on_sig,

            HS_out => VGA_HS, VS_out => VGA_VS,

            game_state_in => game_state,

            p1_x_in => p1_x, p1_y_in => p1_y, p2_x_in => p2_x, p2_y_in => p2_y,

            p1_trail_in => ram_p1_data_out(0), p2_trail_in => ram_p2_data_out(0),

            p1_score_in => p1_score, p2_score_in => p2_score,

            

            -- PUERTOS DE DIRECCIÓN CONECTADOS

            p1_dir_in => p1_dir_sig,

            p2_dir_in => p2_dir_sig,

            

            VGA_R_out => vga_r_game, VGA_G_out => vga_g_game, VGA_B_out => vga_b_game

        );

        

    -- 4. GRAFICOS MENU 

    int_x <= to_integer(unsigned(pixel_x));

    int_y <= to_integer(unsigned(pixel_y));

    

    -- Logo TRON

    logo_addr <= std_logic_vector(to_unsigned( ((int_y - 80)/3)*LOGO_W + ((int_x - 185)/3), 11))

              when (int_y >= 80 and int_y < 80+(LOGO_H*3)) and (int_x >= 185 and int_x < 185+(LOGO_W*3))

              else (others=>'0');

    

    ROM_TRON_LOGO : menu_rom generic map (INIT_FILE => "tron_text.mif", ADDR_WIDTH => 11)

                                 port map (clock => clk_vga, address => logo_addr, q => logo_q);

        

    -- Numero 1 

    num1_addr <= std_logic_vector(to_unsigned( ((int_y - 307)/2)*NUM_W + ((int_x - 209)/2), 8))

              when (int_y >= 307 and int_y < 307+(NUM_H*2)) and (int_x >= 209 and int_x < 209+(NUM_W*2))

              else (others => '0');



    ROM_NUM_1 : menu_rom generic map (INIT_FILE => "1.mif", ADDR_WIDTH => 8)

                             port map (clock => clk_vga, address => num1_addr, q => num1_q);

        

    -- Numero 2 

    num2_addr <= std_logic_vector(to_unsigned( ((int_y - 307)/2)*NUM_W + ((int_x - 409)/2), 8))

              when (int_y >= 307 and int_y < 307+(NUM_H*2)) and (int_x >= 409 and int_x < 409+(NUM_W*2))

              else (others => '0');



    ROM_NUM_2 : menu_rom generic map (INIT_FILE => "2.mif", ADDR_WIDTH => 8)

                             port map (clock => clk_vga, address => num2_addr, q => num2_q);



    -- Pintar el Menú

    process(video_on_sig, int_x, int_y, menu_selection, logo_q, num1_q, num2_q)

    begin

        vga_r_menu <= "0000"; vga_g_menu <= "0000"; vga_b_menu <= "0000";

        

        if video_on_sig = '1' then

            -- LOGO

            if (int_y >= 80 and int_y < 80+(LOGO_H*3)) and (int_x >= 182 and int_x < 182+(LOGO_W*3)) then

                if logo_q /= "101010101010" then

                    vga_r_menu <= logo_q(11 downto 8); vga_g_menu <= logo_q(7 downto 4); vga_b_menu <= logo_q(3 downto 0);

                end if;

            end if;



            -- CAJA 1 (1 Player)

            if (int_x >= 150 and int_x < 290) and (int_y >= 300 and int_y < 350) then

                if menu_selection = '0' and (int_x < 155 or int_x > 285 or int_y < 305 or int_y > 345) then

                    vga_r_menu <= "1111"; vga_g_menu <= "1111"; vga_b_menu <= "1111"; -- Borde Blanco (Seleccionado)

                else

                    vga_r_menu <= "1111"; -- Fondo Rojo (Des-seleccionado)

                    if (int_y >= 307 and int_y < 307+(NUM_H*2)) and (int_x >= 209 and int_x < 209+(NUM_W*2)) then

                        if num1_q /= "101010101010" then vga_r_menu <= "1111"; vga_g_menu <= "1111"; vga_b_menu <= "1111"; end if;

                    end if;

                end if;

            end if;



            -- CAJA 2 (2 Player)

            if (int_x >= 350 and int_x < 490) and (int_y >= 300 and int_y < 350) then

                if menu_selection = '1' and (int_x < 355 or int_x > 485 or int_y < 305 or int_y > 345) then

                    vga_r_menu <= "1111"; vga_g_menu <= "1111"; vga_b_menu <= "1111"; -- Borde Blanco (Seleccionado)

                else

                    vga_b_menu <= "1111"; -- Fondo Azul (Des-seleccionado)

                    if (int_y >= 307 and int_y < 307+(NUM_H*2)) and (int_x >= 409 and int_x < 409+(NUM_W*2)) then

                        if num2_q /= "101010101010" then vga_r_menu <= "1111"; vga_g_menu <= "1111"; vga_b_menu <= "1111"; end if;

                    end if;

                end if;

            end if;

        end if;

    end process;

    

    -- Puntuación

    s_p1_score_vec <= std_logic_vector(to_unsigned(p1_score, 4));

    s_p2_score_vec <= std_logic_vector(to_unsigned(p2_score, 4));

    Inst_Score_P1 : entity work.bin_to_sseg port map (bin => s_p1_score_vec, sseg => HEX0_out);

    Inst_Score_P2 : entity work.bin_to_sseg port map (bin => s_p2_score_vec, sseg => HEX2_out);



    -- 5. MULTIPLEXOR FINAL (JUEGO vs MENU)

    process(current_sys_state, vga_r_game, vga_g_game, vga_b_game, vga_r_menu, vga_g_menu, vga_b_menu)

    begin

        if current_sys_state = S_GAME then

            VGA_R <= vga_r_game;

            VGA_G <= vga_g_game;

            VGA_B <= vga_b_game;

        else

            VGA_R <= vga_r_menu;

            VGA_G <= vga_g_menu;

            VGA_B <= vga_b_menu;

        end if;

    end process;



end Behavioral;
