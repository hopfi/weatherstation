----------------------------------------------------------------------------------
-- Name: Daniel Hopfinger
-- Date: 27.09.2021
-- Module: data_converter.vhd
-- Description:
-- Wrapper module which converts the sensors environment data to bcd data, that can be output to the display.
--
-- History:
-- Version  | Date       | Information
-- ----------------------------------------
--  0.0.1   | 27.09.2021 | Initial version.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library gen;


entity data_converter is
    port (
        i_clk            : in  std_logic;                       --! Clk input
        i_rst            : in  std_logic;                       --! Reset input

        --! Sensor data output
        i_bin_data_temp     : in  std_logic_vector(19 downto 0);
        i_bin_data_pres     : in  std_logic_vector(19 downto 0);
        i_bin_data_hum      : in  std_logic_vector(15 downto 0);
        i_bin_data_valid    : in  std_logic;

        --! BCD data input
        o_bcd_temp_sgn   : out std_logic;
        o_bcd_temp       : out std_logic_vector(11 downto 0);
        o_bcd_pres       : out std_logic_vector(23 downto 0);
        o_bcd_hum        : out std_logic_vector(7 downto 0);
        o_bcd_valid      : out std_logic;
        i_bcd_busy       : in  std_logic
    );
end entity data_converter;

architecture struct of data_converter is

    signal raw_bin_T        : std_logic_vector(31 downto 0);
    signal raw_bin_P        : std_logic_vector(31 downto 0);
    signal raw_bin_H        : std_logic_vector(31 downto 0);
    signal raw_bin_vld      : std_logic;
    signal comp_bin_T       : std_logic_vector(31 downto 0);
    signal comp_bin_P       : std_logic_vector(31 downto 0);
    signal comp_bin_H       : std_logic_vector(31 downto 0);
    signal comp_bin_vld     : std_logic;
    signal comp_bin_vld_r1  : std_logic;
    signal data_comp_vld    : std_logic;
    signal bin_T            : std_logic_vector(31 downto 0);
    signal bin_P            : std_logic_vector(31 downto 0);
    signal bin_H            : std_logic_vector(31 downto 0);
    signal bin_T_busy       : std_logic;
    signal bin_P_busy       : std_logic;
    signal bin_H_busy       : std_logic;
    signal bin_vld          : std_logic;

    signal bcd_T : std_logic_vector(15 downto 0);
    signal bcd_T_vld : std_logic;
    signal bcd_P : std_logic_vector(23 downto 0);
    signal bcd_P_vld : std_logic;
    signal bcd_H : std_logic_vector(7 downto 0);
    signal bcd_H_vld : std_logic;

    signal bcd_temp : std_logic_vector(11 downto 0);
    signal bcd_pres : std_logic_vector(23 downto 0);
    signal bcd_hum  : std_logic_vector(7 downto 0);

    signal bcd_T_vld_reg : std_logic;
    signal bcd_P_vld_reg : std_logic;
    signal bcd_H_vld_reg : std_logic;

    signal bcd_vld_temp : std_logic;
    signal bcd_vld      : std_logic;

begin


    data_comp : entity gen.bme280_data_comp(rtl)
    port map(
        i_clk            => i_clk,
        i_rst            => i_rst,
        i_adc_T          => raw_bin_T,
        i_adc_P          => raw_bin_P,
        i_adc_H          => raw_bin_H,
        i_adc_vld        => raw_bin_vld,
        o_temperature    => comp_bin_T,
        o_pressure       => comp_bin_P,
        o_humidity       => comp_bin_H,
        o_valid          => comp_bin_vld
    );
    raw_bin_T <=  x"000" & i_bin_data_temp;
    raw_bin_P <=  x"000" & i_bin_data_pres;
    raw_bin_H <= x"0000" & i_bin_data_hum;
    raw_bin_vld <= i_bin_data_valid;

    --bin_T <= std_logic_vector(resize(signed(comp_bin_T) * 1/10, 31));
    --bin_T <= comp_bin_T * 2**16/10 >> 16;
    bin_T <= comp_bin_T;
    bin_P <= x"00" & comp_bin_P(31 downto 8);
    bin_H <= "000" & x"00" & comp_bin_H(31 downto 11);
    --bin_vld <= comp_bin_vld when (bin_T_busy = '0') and (bin_P_busy = '0') and (bin_H_busy = '0') else '0';
    bin_vld <= data_comp_vld when (bin_T_busy = '0') and (bin_H_busy = '0') else '0';

    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                comp_bin_vld_r1 <= '0';
                data_comp_vld <= '0';
            else
                data_comp_vld <= '0';
                comp_bin_vld_r1 <= comp_bin_vld;

                if comp_bin_vld = '1' and comp_bin_vld_r1 = '0' then
                    data_comp_vld <= '1';
                end if;
            end if;
        end if;
    end process;

    temp_bcd : entity gen.bin_to_bcd(rtl)
    generic map(
        G_BIN_BITSIZE => 32, --! Amount of bits for the binary integer
        G_BCD_BITSIZE => 16  --! Amount of bits for the bcd integer
    )
    port map(
        i_clk        => i_clk,
        i_rst        => i_rst,
        o_busy       => bin_T_busy,
        i_bin_input  => bin_T,
        i_bin_vld    => bin_vld,
        o_bcd_output => bcd_T,
        o_bcd_vld    => bcd_T_vld
    );
    bcd_temp <= bcd_T(15 downto 4);
    o_bcd_temp <= bcd_temp;
    o_bcd_temp_sgn <= bin_T(bin_T'left);

    pres_bcd : entity gen.bin_to_bcd(rtl)
    generic map(
        G_BIN_BITSIZE => 32, --! Amount of bits for the binary integer
        G_BCD_BITSIZE => 24  --! Amount of bits for the bcd integer
    )
    port map(
        i_clk        => i_clk,
        i_rst        => i_rst,
        o_busy       => bin_P_busy,
        i_bin_input  => bin_P,
        i_bin_vld    => bin_vld,
        o_bcd_output => bcd_P,
        o_bcd_vld    => bcd_P_vld
    );
    bcd_pres <= bcd_P;
    o_bcd_pres <= bcd_pres;

    hum_bcd : entity gen.bin_to_bcd(rtl)
    generic map(
        G_BIN_BITSIZE => 32, --! Amount of bits for the binary integer
        G_BCD_BITSIZE => 8  --! Amount of bits for the bcd integer
    )
    port map(
        i_clk        => i_clk,
        i_rst        => i_rst,
        o_busy       => bin_H_busy,
        i_bin_input  => bin_H,
        i_bin_vld    => bin_vld,
        o_bcd_output => bcd_H,
        o_bcd_vld    => bcd_H_vld
    );
    bcd_hum <= bcd_H;
    o_bcd_hum <= bcd_hum;

    --bcd_vld_temp <= '1' when (bcd_T_vld_reg = '1') and (bcd_P_vld_reg = '1') and (bcd_H_vld_reg = '1') else '0';
    bcd_vld_temp <= '1' when (bcd_T_vld_reg = '1') and (bcd_H_vld_reg = '1') else '0';
    bcd_vld <= bcd_vld_temp when i_bcd_busy = '0' else '0';
    o_bcd_valid <= bcd_vld;
    process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                bcd_T_vld_reg <= '0';
                bcd_P_vld_reg <= '0';
                bcd_H_vld_reg <= '0';
            else
            
                if bcd_T_vld = '1' then
                    bcd_T_vld_reg <= '1';
                end if;

                if bcd_P_vld = '1' then
                    bcd_P_vld_reg <= '1';
                end if;
                
                if bcd_H_vld = '1' then
                    bcd_H_vld_reg <= '1';
                end if;

                --if bcd_T_vld_reg = '1' and bcd_P_vld_reg = '1' and bcd_H_vld_reg = '1' then
                if bcd_T_vld_reg = '1' and bcd_H_vld_reg = '1' then
                    bcd_T_vld_reg <= '0';
                    bcd_P_vld_reg <= '0';
                    bcd_H_vld_reg <= '0';
                end if;

            end if;
        end if;
    end process;

end architecture struct;

