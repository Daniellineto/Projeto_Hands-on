module tb_dummy_aes;

    logic a;
    logic b;
    logic y;

    dummy_aes u_dummy_aes (
        .a(a),
        .b(b),
        .y(y)
    );

    initial begin
        // Casos de teste
        a = 0; b = 0;
        #10 a = 0; b = 1;
        #10 a = 1; b = 0;
        #10 a = 1; b = 1;
        #10;
        $display("Simulação concluída com sucesso!");
        $finish;
    end

    initial begin
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_dummy_aes);
    end

endmodule
