library ieee;

use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

use work.types_pkg.all; 



entity game_logic is

    generic (

        GRID_W : integer := 80;

        GRID_H : integer := 60;

        MAX_SCORE : integer := 5;

        RAM_ADDR_W : integer := 13

    );

    port (

        clk_game : in std_logic; -- 10 Hz

        rst : in std_logic;

        

        -- Botones

        btn_start : in std_logic;

        btn_p1_up : in std_logic; btn_p1_down: in std_logic;

        btn_p1_left: in std_logic; btn_p1_right: in std_logic;

        btn_p2_up : in std_logic; btn_p2_down: in std_logic;

        btn_p2_left: in std_logic; btn_p2_right: in std_logic;

        

        -- Colisión

        collision_data_p1_in : in std_logic;

        collision_data_p2_in : in std_logic;

        

        -- RAM P1 

        ram_p1_we_out : out std_logic; ram_p1_addr_out : out std_logic_vector(RAM_ADDR_W-1 downto 0); ram_p1_data_out : out std_logic;

        -- RAM P2 

        ram_p2_we_out : out std_logic; ram_p2_addr_out : out std_logic_vector(RAM_ADDR_W-1 downto 0); ram_p2_data_out : out std_logic;

        

        -- Dirección para leer 

        ram_check_addr_out : out std_logic_vector(RAM_ADDR_W-1 downto 0);

        

        -- Puertos para limpiar RAM

        ram_clear_out : out std_logic; ram_clear_done_in : in std_logic;

        

        -- Salidas de estado y posición

        game_state_out : out std_logic_vector(2 downto 0);

        p1_x_out : out integer range 0 to GRID_W-1; p1_y_out : out integer range 0 to GRID_H-1;

        p2_x_out : out integer range 0 to GRID_W-1; p2_y_out : out integer range 0 to GRID_H-1;

        

        -- SALIDAS DE DIRECCIÓN 

        p1_dir_out : out T_Direction; p2_dir_out : out T_Direction;

        

        p1_score_out : out integer range 0 to 9; p2_score_out : out integer range 0 to 9

    );

end entity game_logic;



architecture FSM of game_logic is



    type T_GameState is (

        S_IDLE, S_CLEAR_RAM, S_CLEAN_FOR_IDLE, S_INIT_ROUND, S_RUN_WRITE, S_RUN_CHECK_P1,

        S_RUN_CHECK_P2, S_RUN_MOVE, S_CRASHED, S_WAIT_RELEASE, 

        S_GAME_OVER_GREEN, S_GAME_OVER_WINNER, S_GAME_OVER_WAIT

    );

    

    signal current_state : T_GameState;

    signal p1_dir_reg : T_Direction; signal p2_dir_reg : T_Direction;

    signal p1_x_reg, p1_y_reg : integer range 0 to GRID_W-1;

    signal p2_x_reg, p2_y_reg : integer range 0 to GRID_W-1;

    signal p1_score_reg, p2_score_reg : integer range 0 to 9;

    

    signal p1_x_trail_reg, p1_y_trail_reg : integer range 0 to GRID_W-1;

    signal p2_x_trail_reg, p2_y_trail_reg : integer range 0 to GRID_W-1;



    signal p1_col_p1_trail : std_logic; signal p1_col_p2_trail : std_logic;

    signal p2_col_p1_trail : std_logic; signal p2_col_p2_trail : std_logic;

    

    signal next_state : T_GameState;

    signal p1_dir_next : T_Direction; signal p2_dir_next : T_Direction;

    signal p1_x_next : integer range -1 to GRID_W; signal p1_y_next : integer range -1 to GRID_H;

    signal p2_x_next : integer range -1 to GRID_W; signal p2_y_next : integer range -1 to GRID_H;

    signal p1_score_next, p2_score_next : integer range 0 to 9;



    constant GAME_OVER_CYCLES : integer := 20; 

    signal game_over_timer_reg : integer range 0 to GAME_OVER_CYCLES;

    signal game_over_timer_done : std_logic;

    

    -- Constantes de límites de juego

    constant MIN_X_COLLISION : integer := 2; constant MIN_Y_COLLISION : integer := 5;

    constant MAX_X_COLLISION : integer := 77; constant MAX_Y_COLLISION : integer := 57;

    constant P1_START_Y : integer := 15; constant P2_START_Y : integer := P1_START_Y + 30; 

    constant SPRITE_GRID_W_H : integer := 2; constant SPRITE_GRID_H_H : integer := 1;

    constant SPRITE_GRID_W_V : integer := 1; constant SPRITE_GRID_H_V : integer := 2;



    function to_ram_addr(x, y: integer) return std_logic_vector is

        variable safe_x, safe_y : integer;

        variable addr_int : integer;

    begin

        safe_x := x;

        if x < 0 then safe_x := 0; end if;

        if x >= GRID_W then safe_x := GRID_W - 1; end if;

        safe_y := y;

        if y < 0 then safe_y := 0; end if;

        if y >= GRID_H then safe_y := GRID_H - 1; end if;

        addr_int := (safe_y * GRID_W) + safe_x;

        return std_logic_vector(to_unsigned(addr_int, RAM_ADDR_W));

    end function to_ram_addr;



begin



    -- Lógica Combinacional

    process(current_state, rst, btn_start,

            btn_p1_up, btn_p1_down, btn_p1_left, btn_p1_right,

            btn_p2_up, btn_p2_down, btn_p2_left, btn_p2_right,

            p1_x_reg, p1_y_reg, p2_x_reg, p2_y_reg,

            p1_dir_reg, p2_dir_reg,

            p1_score_reg, p2_score_reg,

            collision_data_p1_in, collision_data_p2_in,

            p1_col_p1_trail, p1_col_p2_trail, p2_col_p1_trail, p2_col_p2_trail,

            p1_x_next, p1_y_next, p2_x_next, p2_y_next,

            p1_x_trail_reg, p1_y_trail_reg, p2_x_trail_reg, p2_y_trail_reg,

            ram_clear_done_in, game_over_timer_done, 

            p1_score_next, p2_score_next)

            

        variable v_p1_crashed, v_p2_crashed : boolean;

        

    begin

        -- Asignaciones

        next_state <= current_state;

        p1_x_next <= p1_x_reg; p1_y_next <= p1_y_reg;

        p2_x_next <= p2_x_reg; p2_y_next <= p2_y_reg;

        p1_dir_next <= p1_dir_reg; p2_dir_next <= p2_dir_reg;

        p1_score_next<= p1_score_reg; p2_score_next<= p2_score_reg;

        

        ram_p1_we_out <= '0'; ram_p2_we_out <= '0';

        ram_p1_addr_out <= (others => '0'); ram_p2_addr_out <= (others => '0');

        ram_p1_data_out <= '0'; ram_p2_data_out <= '0';

        ram_check_addr_out <= (others => '0');

        ram_clear_out <= '0';

        v_p1_crashed := false; v_p2_crashed := false;



        case current_state is

        

            when S_IDLE =>

                p1_score_next <= 0; p2_score_next <= 0;

                p1_x_next <= MAX_X_COLLISION - 1; p1_y_next <= P1_START_Y; p1_dir_next <= LEFT;

                p2_x_next <= MAX_X_COLLISION - 1; p2_y_next <= P2_START_Y; p2_dir_next <= LEFT;

                

                if btn_start = '1' then next_state <= S_CLEAR_RAM; end if;

            

            when S_CLEAR_RAM =>

                ram_clear_out <= '1';

                if ram_clear_done_in = '1' then next_state <= S_INIT_ROUND; end if;

            

            when S_CLEAN_FOR_IDLE =>

                ram_clear_out <= '1';

                if ram_clear_done_in = '1' then next_state <= S_IDLE; end if;

            

            when S_INIT_ROUND =>

                p1_x_next <= MAX_X_COLLISION - 1; p1_y_next <= P1_START_Y; p1_dir_next <= LEFT;

                p2_x_next <= MAX_X_COLLISION - 1; p2_y_next <= P2_START_Y; p2_dir_next <= LEFT;

                next_state <= S_RUN_WRITE;



            when S_RUN_WRITE =>

                ram_p1_we_out <= '1'; ram_p1_data_out <= '1'; ram_p1_addr_out <= to_ram_addr(p1_x_trail_reg, p1_y_trail_reg);

                ram_p2_we_out <= '1'; ram_p2_data_out <= '1'; ram_p2_addr_out <= to_ram_addr(p2_x_trail_reg, p2_y_trail_reg);

                

                if btn_p1_up = '1' and p1_dir_reg /= DOWN then p1_dir_next <= UP; end if;

                if btn_p1_down = '1' and p1_dir_reg /= UP then p1_dir_next <= DOWN; end if;

                if btn_p1_left = '1' and p1_dir_reg /= RIGHT then p1_dir_next <= LEFT; end if;

                if btn_p1_right = '1' and p1_dir_reg /= LEFT then p1_dir_next <= RIGHT; end if;

                

                if btn_p2_up = '1' and p2_dir_reg /= DOWN then p2_dir_next <= UP; end if;

                if btn_p2_down = '1' and p2_dir_reg /= UP then p2_dir_next <= DOWN; end if;

                if btn_p2_left = '1' and p2_dir_reg /= RIGHT then p2_dir_next <= LEFT; end if;

                if btn_p2_right = '1' and p2_dir_reg /= LEFT then p2_dir_next <= RIGHT; end if;

                

                next_state <= S_RUN_CHECK_P1;

                

            when S_RUN_CHECK_P1 =>

                case p1_dir_reg is

                    when UP => p1_y_next <= p1_y_reg - 1; when DOWN => p1_y_next <= p1_y_reg + 1;

                    when LEFT => p1_x_next <= p1_x_reg - 1; when RIGHT => p1_x_next <= p1_x_reg + 1;

                end case;

                case p2_dir_reg is

                    when UP => p2_y_next <= p2_y_reg - 1; when DOWN => p2_y_next <= p2_y_reg + 1;

                    when LEFT => p2_x_next <= p2_x_reg - 1; when RIGHT => p2_x_next <= p2_x_reg + 1;

                end case;

                ram_check_addr_out <= to_ram_addr(p1_x_next, p1_y_next);

                next_state <= S_RUN_CHECK_P2;

                

            when S_RUN_CHECK_P2 =>

                case p1_dir_reg is

                    when UP => p1_y_next <= p1_y_reg - 1; when DOWN => p1_y_next <= p1_y_reg + 1;

                    when LEFT => p1_x_next <= p1_x_reg - 1; when RIGHT => p1_x_next <= p1_x_reg + 1;

                end case;

                case p2_dir_reg is

                    when UP => p2_y_next <= p2_y_reg - 1; when DOWN => p2_y_next <= p2_y_reg + 1;

                    when LEFT => p2_x_next <= p2_x_reg - 1; when RIGHT => p2_x_next <= p2_x_reg + 1;

                end case;

                ram_check_addr_out <= to_ram_addr(p2_x_next, p2_y_next);

                next_state <= S_RUN_MOVE;

            

            when S_RUN_MOVE =>

                case p1_dir_reg is

                    when UP => p1_y_next <= p1_y_reg - 1; when DOWN => p1_y_next <= p1_y_reg + 1;

                    when LEFT => p1_x_next <= p1_x_reg - 1; when RIGHT => p1_x_next <= p1_x_reg + 1;

                end case;

                case p2_dir_reg is

                    when UP => p2_y_next <= p2_y_reg - 1; when DOWN => p2_y_next <= p2_y_reg + 1;

                    when LEFT => p2_x_next <= p2_x_reg - 1; when RIGHT => p2_x_next <= p2_x_reg + 1;

                end case;

            

                if (p1_dir_reg = LEFT) then

                    if (p1_x_next < MIN_X_COLLISION) then v_p1_crashed := true; end if;

                elsif (p1_dir_reg = RIGHT) then

                    if (p1_x_next + SPRITE_GRID_W_H - 1 > MAX_X_COLLISION) then v_p1_crashed := true; end if;

                elsif (p1_dir_reg = UP) then

                    if (p1_y_next < MIN_Y_COLLISION) then v_p1_crashed := true; end if;

                elsif (p1_dir_reg = DOWN) then

                    if (p1_y_next + SPRITE_GRID_H_V - 1 > MAX_Y_COLLISION) then v_p1_crashed := true; end if;

                end if;

                

                if (p2_dir_reg = LEFT) then

                    if (p2_x_next < MIN_X_COLLISION) then v_p2_crashed := true; end if;

                elsif (p2_dir_reg = RIGHT) then

                    if (p2_x_next + SPRITE_GRID_W_H - 1 > MAX_X_COLLISION) then v_p2_crashed := true; end if;

                elsif (p2_dir_reg = UP) then

                    if (p2_y_next < MIN_Y_COLLISION) then v_p2_crashed := true; end if;

                elsif (p2_dir_reg = DOWN) then

                    if (p2_y_next + SPRITE_GRID_H_V - 1 > MAX_Y_COLLISION) then v_p2_crashed := true; end if;

                end if;

                

                if (p1_col_p1_trail = '1' or p1_col_p2_trail = '1') then v_p1_crashed := true; end if;

                if (p2_col_p1_trail = '1' or p2_col_p2_trail = '1') then v_p2_crashed := true; end if;

                if p1_x_next = p2_x_next and p1_y_next = p2_y_next then

                    v_p1_crashed := true; v_p2_crashed := true;

                end if;



                if v_p1_crashed or v_p2_crashed then

                    next_state <= S_CRASHED;

                    

                    -- LÓGICA DE PUNTAJE FINAL: QUIEN CHOCA SUMA PUNTO

                    if v_p1_crashed and not v_p2_crashed then 

                        p1_score_next <= p1_score_reg + 1; -- P1 (Rojo) choca, P1 suma punto

                    end if;

                    if v_p2_crashed and not v_p1_crashed then 

                        p2_score_next <= p2_score_reg + 1; -- P2 (Azul) choca, P2 suma punto

                    end if;

                    

                else

                    next_state <= S_RUN_WRITE;

                end if;



            when S_CRASHED =>

                if p1_score_next >= MAX_SCORE or p2_score_next >= MAX_SCORE then

                    next_state <= S_GAME_OVER_GREEN;

                else

                    if (btn_start = '1') then next_state <= S_WAIT_RELEASE; end if;

                end if;



            when S_WAIT_RELEASE =>

                if (btn_start = '0') then next_state <= S_CLEAR_RAM; end if;



            when S_GAME_OVER_GREEN =>

                if game_over_timer_done = '1' then next_state <= S_GAME_OVER_WINNER; end if;

                

            when S_GAME_OVER_WINNER =>

                if btn_start = '1' then next_state <= S_GAME_OVER_WAIT; end if;

                

            when S_GAME_OVER_WAIT =>

                if btn_start = '0' then next_state <= S_CLEAN_FOR_IDLE; end if;

                

        end case;

    end process;



    -- Lógica Secuencial

    process(clk_game, rst)

    begin

        if rst = '1' then

            current_state <= S_IDLE;

            p1_score_reg <= 0; p2_score_reg <= 0;

            p1_dir_reg <= LEFT; p2_dir_reg <= LEFT;

            p1_x_reg <= MAX_X_COLLISION - 1; p1_y_reg <= P1_START_Y;

            p2_x_reg <= MAX_X_COLLISION - 1; p2_y_reg <= P2_START_Y;

            p1_x_trail_reg <= MAX_X_COLLISION - 1; p1_y_trail_reg <= P1_START_Y;

            p2_x_trail_reg <= MAX_X_COLLISION - 1; p2_y_trail_reg <= P2_START_Y;

            p1_col_p1_trail <= '0'; p1_col_p2_trail <= '0';

            p2_col_p1_trail <= '0'; p2_col_p2_trail <= '0';

            game_over_timer_reg <= 0; game_over_timer_done <= '0'; 

            

        elsif rising_edge(clk_game) then

            

            current_state <= next_state;

            p1_score_reg <= p1_score_next; p2_score_reg <= p2_score_next;

            p1_dir_reg <= p1_dir_next; p2_dir_reg <= p2_dir_next;

            

            if current_state = S_RUN_CHECK_P1 then

                p1_col_p1_trail <= collision_data_p1_in; p1_col_p2_trail <= collision_data_p2_in;

            elsif current_state = S_RUN_CHECK_P2 then

                p2_col_p1_trail <= collision_data_p1_in; p2_col_p2_trail <= collision_data_p2_in;

            end if;

            

            if current_state = S_RUN_MOVE and next_state = S_RUN_WRITE then

                p1_x_reg <= p1_x_next; p1_y_reg <= p1_y_next;

                p2_x_reg <= p2_x_next; p2_y_reg <= p2_y_next;

                p1_x_trail_reg <= p1_x_reg; p1_y_trail_reg <= p1_y_reg;

                p2_x_trail_reg <= p2_x_reg; p2_y_trail_reg <= p2_y_reg;

                

            elsif next_state = S_INIT_ROUND then

                p1_x_reg <= MAX_X_COLLISION - 1; p1_y_reg <= P1_START_Y;

                p2_x_reg <= MAX_X_COLLISION - 1; p2_y_reg <= P2_START_Y;

                p1_x_trail_reg <= MAX_X_COLLISION - 1; p1_y_trail_reg <= P1_START_Y;

                p2_x_trail_reg <= MAX_X_COLLISION - 1; p2_y_trail_reg <= P2_START_Y;

                

            elsif next_state = S_IDLE then

                p1_x_reg <= p1_x_next; p1_y_reg <= p1_y_next; p1_dir_reg <= p1_dir_next;

                p2_x_reg <= p2_x_next; p2_y_reg <= p2_y_next; p2_dir_reg <= p2_dir_next;

                p1_x_trail_reg <= p1_x_next; p1_y_trail_reg <= p1_y_next;

                p2_x_trail_reg <= p2_x_next; p2_y_trail_reg <= p2_y_next;

            end if;

            

            game_over_timer_done <= '0'; 

            

            if next_state = S_GAME_OVER_GREEN and current_state /= S_GAME_OVER_GREEN then

                game_over_timer_reg <= 0;

            elsif current_state = S_GAME_OVER_GREEN then

                if game_over_timer_reg < GAME_OVER_CYCLES then

                    game_over_timer_reg <= game_over_timer_reg + 1;

                else

                    game_over_timer_done <= '1'; 

                end if;

            end if;

            

        end if;

    end process;



    -- Salidas

    p1_x_out <= p1_x_reg; p1_y_out <= p1_y_reg;

    p2_x_out <= p2_x_reg; p2_y_out <= p2_y_reg;

    p1_score_out <= p1_score_reg; p2_score_out <= p2_score_reg;

    p1_dir_out <= p1_dir_reg; p2_dir_out <= p2_dir_reg;

    

    game_state_out <= "000" when current_state = S_IDLE else

                      "001" when current_state = S_CLEAR_RAM else

                      "001" when current_state = S_CLEAN_FOR_IDLE else

                      "010" when current_state = S_INIT_ROUND else

                      "011" when current_state = S_RUN_WRITE else

                      "011" when current_state = S_RUN_CHECK_P1 else

                      "011" when current_state = S_RUN_CHECK_P2 else

                      "011" when current_state = S_RUN_MOVE else

                      "100" when current_state = S_CRASHED else

                      "100" when current_state = S_WAIT_RELEASE else

                      "110" when current_state = S_GAME_OVER_GREEN else

                      "111" when current_state = S_GAME_OVER_WINNER else

                      "111"; -- S_GAME_OVER_WAIT



end FSM;