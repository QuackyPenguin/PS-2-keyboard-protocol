// Constraints
class constraints;

    randc bit [3:0] v1;
    randc bit [3:0] v2;
    rand bit [3:0] v3;
    rand bit [3:0] v4;
    
    constraint c1 { v1 > 4'b0100; }
    constraint c2 { ! (v1 inside {[4'h8:4'hF]}); }
    constraint c3 { v2 == v1*2+1; }
    constraint c4 { v3 dist {0:=50, [1:5]:=10, [5:15]:=0 }; }
    constraint c5 { v4 dist {0:/50, [1:5]:/10, [5:15]:/0 }; }

endclass

// Testbench
module testbench_constraints;

    constraints c;
    
    initial begin
        c = new;
        
        for (int i = 0; i < 20; i++) begin
            c.randomize();
            $display(
                "v1 = %h, v2 = %h, v3 = %h, v4 = %h",
                c.v1, c.v2, c.v3, c.v4
            );
        end
        $finish;
    end

endmodule
