package com.vendingmachiinetycoon.app;

import android.os.Bundle;

import androidx.activity.EdgeToEdge;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        // The game draws behind the status and navigation bars, as the original app did.
        EdgeToEdge.enable(this);
        super.onCreate(savedInstanceState);
    }
}
