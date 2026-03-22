package com.iamborednowok.smartcalc;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Register native plugins BEFORE super.onCreate
        registerPlugin(LLMPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
