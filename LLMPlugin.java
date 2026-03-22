package com.iamborednowok.smartcalc;

import android.util.Log;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

@CapacitorPlugin(name = "LLM")
public class LLMPlugin extends Plugin {
    private static final String TAG = "LLMPlugin";
    private static final String MODEL_FILENAME = "gemma3-1b-it-int4.task";
    private static final String MODEL_URL =
        "https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task";
    private LlmInference llmInference = null;

    private File getModelFile() {
        File dir = new File(getContext().getFilesDir(), "llm");
        dir.mkdirs();
        return new File(dir, MODEL_FILENAME);
    }

    @PluginMethod
    public void getStatus(PluginCall call) {
        File f = getModelFile();
        JSObject ret = new JSObject();
        ret.put("modelExists", f.exists() && f.length() > 50_000_000L);
        ret.put("modelPath", f.getAbsolutePath());
        ret.put("modelSize", f.exists() ? f.length() : 0);
        ret.put("loaded", llmInference != null);
        call.resolve(ret);
    }

    // ✅ FIX: Dùng RETURN_PROMISE thay RETURN_CALLBACK
    // Progress báo qua notifyListeners("downloadProgress") 
    // JS gọi LLM.downloadModel({}) trả về Promise bình thường
    @PluginMethod
    public void downloadModel(PluginCall call) {
        File modelFile = getModelFile();

        // Đã tải xong → resolve ngay
        if (modelFile.exists() && modelFile.length() > 50_000_000L) {
            JSObject ret = new JSObject();
            ret.put("status", "cached");
            ret.put("path", modelFile.getAbsolutePath());
            call.resolve(ret);
            return;
        }

        new Thread(() -> {
            try {
                URL url = new URL(MODEL_URL);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setConnectTimeout(15_000);
                conn.setReadTimeout(60_000);
                conn.setInstanceFollowRedirects(true);
                conn.connect();

                int httpCode = conn.getResponseCode();
                if (httpCode < 200 || httpCode >= 300) {
                    modelFile.delete();
                    call.reject("HTTP error: " + httpCode);
                    return;
                }

                long total = conn.getContentLengthLong();

                try (InputStream in = conn.getInputStream();
                     FileOutputStream out = new FileOutputStream(modelFile)) {
                    byte[] buf = new byte[65536]; // 64KB buffer (tăng từ 32KB → nhanh hơn)
                    long downloaded = 0;
                    long lastReport = 0;
                    int n;
                    while ((n = in.read(buf)) != -1) {
                        out.write(buf, 0, n);
                        downloaded += n;
                        long now = System.currentTimeMillis();
                        if (now - lastReport > 400) {
                            lastReport = now;
                            // ✅ Dùng notifyListeners thay vì call.resolve() nhiều lần
                            JSObject p = new JSObject();
                            p.put("status", "downloading");
                            p.put("downloaded", downloaded);
                            p.put("total", total);
                            p.put("percent", total > 0 ? (int)(downloaded * 100 / total) : 0);
                            p.put("mb", String.format("%.1f", downloaded / 1048576.0));
                            p.put("totalMb", String.format("%.0f", total / 1048576.0));
                            notifyListeners("downloadProgress", p);
                        }
                    }
                    out.flush();
                }

                // Kiểm tra file tải xong hợp lệ
                if (modelFile.length() < 50_000_000L) {
                    modelFile.delete();
                    call.reject("Download incomplete: file too small");
                    return;
                }

                JSObject ret = new JSObject();
                ret.put("status", "done");
                ret.put("path", modelFile.getAbsolutePath());
                call.resolve(ret); // ✅ Chỉ gọi resolve() 1 lần duy nhất

            } catch (Exception e) {
                Log.e(TAG, "Download error", e);
                if (modelFile.exists()) modelFile.delete();
                call.reject("Download failed: " + e.getMessage());
            }
        }).start();
    }

    @PluginMethod
    public void loadModel(PluginCall call) {
        String path = call.getString("path", getModelFile().getAbsolutePath());
        new Thread(() -> {
            try {
                if (llmInference != null) {
                    llmInference.close();
                    llmInference = null;
                }
                LlmInference.LlmInferenceOptions opts = LlmInference.LlmInferenceOptions.builder()
                    .setModelPath(path)
                    .setMaxTokens(512)
                    .build();
                llmInference = LlmInference.createFromOptions(getContext(), opts);
                call.resolve();
            } catch (Exception e) {
                Log.e(TAG, "Load error", e);
                call.reject("Load failed: " + e.getMessage());
            }
        }).start();
    }

    @PluginMethod
    public void runInference(PluginCall call) {
        if (llmInference == null) {
            call.reject("Model not loaded");
            return;
        }
        String prompt = call.getString("prompt", "");
        new Thread(() -> {
            try {
                String result = llmInference.generateResponse(prompt);
                JSObject ret = new JSObject();
                ret.put("result", result);
                call.resolve(ret);
            } catch (Exception e) {
                Log.e(TAG, "Inference error", e);
                call.reject("Inference failed: " + e.getMessage());
            }
        }).start();
    }

    @Override
    protected void handleOnDestroy() {
        if (llmInference != null) {
            try { llmInference.close(); } catch (Exception ignored) {}
            llmInference = null;
        }
        super.handleOnDestroy();
    }
}
