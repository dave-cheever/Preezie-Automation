package com.preezie.runner;
import com.intuit.karate.junit5.Karate;

public class ApiTestRunner {
    @Karate.Test
    Karate runAll() {
        return Karate.run("classpath:com/preezie/tests/chat-traceid-cms-validation.feature").relativeTo(getClass());
    }
}




