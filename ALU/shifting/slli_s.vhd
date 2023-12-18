library ieee;

use ieee.numeric_std.all;
use work.cpu_defs_pack.all;
use work.bit_vector_natural_pack.all;

entity slli_s is
    port(
        a: in datatype; --data from rs1
        b: in datatype; --zero extended lower five bit of imm (shamt)
        c: out datatype --data in rd
    );

end entity;

architecture behav of slli_s is
    signal shift: integer;

    begin
        
        shift <= bit_vector2natural(b);
        
        process(a, b)
            variable temp: datatype;
        begin
    
            if (shift > 31) then
                c <= (others => '0');
                
            else
                for i in 1 to shift loop
                    temp := a(datasize -2 downto 0) & '0';
                end loop;
                c <= temp;
   
            end if;
        end process;
end architecture;