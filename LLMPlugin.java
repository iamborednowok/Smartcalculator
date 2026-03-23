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
import java.io.IOException;
import java.io.InputStream;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import java.util.concurrent.TimeUnit;

@CapacitorPlugin(name = "LLM")
public class LLMPlugin extends Plugin {
    private static final String TAG = "LLMPlugin";
    private static final String MODEL_FILENAME = "Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task";
    // ?download=true → HuggingFace returns direct CDN URL instead of redirect loop
    private static final String MODEL_URL =
        "https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task?download=true";

    // OkHttp handles redirects correctly AND keeps Authorization header across redirects
    // Unlike HttpURLConnection which silently drops the header on cross-domain redirects
    private static final OkHttpClient httpClient = new OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .followRedirects(true)        // ✅ follows redirects
        .followSslRedirects(true)
        .build();

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
        // Qwen2.5-1.5B task file is ~1.6GB — check at 1GB as minimum valid size
        ret.put("modelExists", f.exists() && f.length() > 1_000_000_000L);
        ret.put("modelPath", f.getAbsolutePath());
        ret.put("modelSize", f.exists() ? f.length() : 0);
        ret.put("loaded", llmInference != null);
        call.resolve(ret);
    }

    @PluginMethod
    public void downloadModel(PluginCall call) {
        File modelFile = getModelFile();

        if (modelFile.exists() && modelFile.length() > 1_000_000_000L) {
            JSObject ret = new JSObject();
            ret.put("status", "cached");
            ret.put("path", modelFile.getAbsolutePath());
            call.resolve(ret);
            return;
        }

        String token = call.getString("hfToken", "");

        new Thread(() -> {
            try {
                // Build request with OkHttp — Authorization header is kept through all redirects
                Request.Builder reqBuilder = new Request.Builder()
                    .url(MODEL_URL)
                    .addHeader("User-Agent", "SmartCalc/1.0");

                if (token != null && !token.isEmpty()) {
                    reqBuilder.addHeader("Authorization", "Bearer " + token);
                }

                Request request = reqBuilder.build();
                Response response = httpClient.newCall(request).execute();

                if (!response.isSuccessful()) {
                    response.close();
                    if (modelFile.exists()) modelFile.delete();
                    call.reject("HTTP error: " + response.code());
                    return;
                }

                long total = response.body() != null ? response.body().contentLength() : -1;

                try (InputStream in = response.body().byteStream();
                     FileOutputStream out = new FileOutputStream(modelFile)) {
                    byte[] buf = new byte[65536]; // 64KB buffer
                    long downloaded = 0;
                    long lastReport = 0;
                    int n;
                    while ((n = in.read(buf)) != -1) {
                        out.write(buf, 0, n);
                        downloaded += n;
                        long now = System.currentTimeMillis();
                        if (now - lastReport > 400) {
                            lastReport = now;
                            JSObject p = new JSObject();
                            p.put("status", "downloading");
                            p.put("downloaded", downloaded);
                            p.put("total", total);
                            p.put("percent", total > 0 ? (int)(downloaded * 100 / total) : 0);
                            p.put("mb", String.format("%.1f", downloaded / 1048576.0));
                            p.put("totalMb", String.format("%.0f", total > 0 ? total / 1048576.0 : 1600));
                            notifyListeners("downloadProgress", p);
                        }
                    }
                    out.flush();
                }
                response.close();

                if (modelFile.length() < 1_000_000_000L) {
                    modelFile.delete();
                    call.reject("Download incomplete: file too small (" + modelFile.length() / 1048576 + "MB)");
                    return;
                }

                JSObject ret = new JSObject();
                ret.put("status", "done");
                ret.put("path", modelFile.getAbsolutePath());
                call.resolve(ret);

            } catch (IOException e) {
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
