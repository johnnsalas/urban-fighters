package com.pixeliagroup.urbanfighters;
import android.app.*;import android.os.*;import android.view.*;import android.webkit.*;
public class MainActivity extends Activity{
 @Override public void onCreate(Bundle b){super.onCreate(b);getWindow().setFlags(1024,1024);getWindow().getDecorView().setSystemUiVisibility(5894);WebView w=new WebView(this);w.getSettings().setJavaScriptEnabled(true);w.getSettings().setDomStorageEnabled(true);w.setBackgroundColor(0xff101426);w.loadUrl("file:///android_asset/game.html");setContentView(w);}
}
