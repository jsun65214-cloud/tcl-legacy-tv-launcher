package local.tv.simplehome;

import android.app.Activity;
import android.app.Dialog;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextClock;
import android.widget.TextView;
import android.widget.Toast;
import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;

public final class MainActivity extends Activity {
    private PackageManager packages;
    private TextView title;
    private TextView subtitle;
    private Dialog drawer;
    private int nextId = 100;

    private static final class Entry {
        final String name;
        final String description;
        final Intent intent;
        final String packageName;
        Entry(String name, String description, Intent intent, String packageName) {
            this.name = name;
            this.description = description;
            this.intent = intent;
            this.packageName = packageName;
        }
    }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        packages = getPackageManager();
        buildHome();
    }

    private int dp(float value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private LinearLayout column() {
        LinearLayout view = new LinearLayout(this);
        view.setOrientation(LinearLayout.VERTICAL);
        return view;
    }
    private TextView text(String value, int size, int color) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL));
        return view;
    }
    private GradientDrawable surface(boolean selected, int radius) {
        GradientDrawable result = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                selected ? new int[]{0xff546582, 0xff303d55} : new int[]{0xff1c2432, 0xff141b27});
        result.setCornerRadius(dp(radius));
        result.setStroke(dp(selected ? 2 : 1), selected ? 0xffedf5ff : 0xff344052);
        return result;
    }
    private void focusStyle(final View view) {
        view.setId(nextId++);
        view.setFocusable(true);
        view.setBackground(surface(false, 14));
        view.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override public void onFocusChange(View target, boolean focused) {
                target.setBackground(surface(focused, 14));
                target.animate().scaleX(focused ? 1.025f : 1f).scaleY(focused ? 1.025f : 1f).setDuration(110);
                if (focused && target.getTag() instanceof Entry) {
                    Entry entry = (Entry) target.getTag();
                    title.setText(entry.name);
                    subtitle.setText(entry.description);
                }
            }
        });
    }
    private Entry app(String name, String description, String packageName) {
        return new Entry(name, description, packages.getLaunchIntentForPackage(packageName), packageName);
    }
    private Entry component(String name, String description, String packageName, String activity) {
        Intent intent = new Intent(Intent.ACTION_MAIN).setComponent(new ComponentName(packageName, activity));
        return new Entry(name, description, intent, packageName);
    }
    private Entry stock() {
        return component("原厂桌面", "返回熟悉的 TCL 首页", "com.tcl.cyberui", "com.tcl.cyberui.MainActivity");
    }
    private Entry television() {
        Intent intent = new Intent("com.tcl.tv").setComponent(new ComponentName("com.tcl.tv", "com.tcl.tv.TVActivity"));
        return new Entry("机顶盒 · HDMI1", "观看机顶盒节目，无需在电视上搜台", intent, "com.tcl.tv");
    }
    private void useApplicationInput() {
        // Use the same public OEM method as CyberUI, without saving over HDMI1.
        if (Build.VERSION.SDK_INT != 17 || !"tcl_901".equals(Build.DEVICE)) return;
        long started = SystemClock.elapsedRealtime();
        try {
            Class<?> managerClass = Class.forName("com.tcl.tvmanager.TTvCommonManager");
            Class<?> sourceClass = Class.forName("com.tcl.tvmanager.vo.EnTCLInputSource");
            Object manager = managerClass.getMethod("getInstance", Context.class)
                    .invoke(null, getApplicationContext());
            Object storage = sourceClass.getField("EN_TCL_STORAGE").get(null);
            Object current = managerClass.getMethod("getCurrentInputSource").invoke(manager);
            if (!storage.equals(current)) {
                managerClass.getMethod("setInputSource", sourceClass, Boolean.TYPE)
                        .invoke(manager, storage, false);
            }
            Object actual = managerClass.getMethod("getCurrentInputSource").invoke(manager);
            android.util.Log.i("SimpleHome", "Application input=" + actual + ", elapsedMs="
                    + (SystemClock.elapsedRealtime() - started) + "; remembered TV input preserved");
        } catch (Exception exception) {
            android.util.Log.w("SimpleHome", "Could not select OEM application input", exception);
        } catch (LinkageError error) {
            android.util.Log.w("SimpleHome", "OEM input interface unavailable", error);
        }
    }
    private void launch(Entry entry) {
        if (entry.intent == null) {
            Toast.makeText(this, "这个入口暂不可用，请从原厂桌面打开", Toast.LENGTH_LONG).show();
            return;
        }
        try {
            Intent intent = new Intent(entry.intent);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            startActivity(intent);
        } catch (RuntimeException exception) {
            Toast.makeText(this, "暂时无法打开，请使用原厂桌面或遥控器", Toast.LENGTH_LONG).show();
        }
    }
    private TextView action(String name, final Runnable run) {
        TextView button = text(name, 16, Color.WHITE);
        button.setGravity(Gravity.CENTER);
        button.setPadding(dp(17), dp(12), dp(17), dp(12));
        focusStyle(button);
        button.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View view) { run.run(); }
        });
        return button;
    }
    private void addAction(LinearLayout row, TextView button) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-2, -2);
        params.leftMargin = dp(10);
        row.addView(button, params);
    }
    private View tile(final Entry entry, boolean compact) {
        LinearLayout tile = column();
        tile.setGravity(Gravity.CENTER);
        tile.setPadding(dp(12), dp(10), dp(12), dp(10));
        tile.setTag(entry);
        focusStyle(tile);
        ImageView icon = new ImageView(this);
        icon.setScaleType(ImageView.ScaleType.FIT_CENTER);
        try {
            if (entry.packageName.equals("com.tcl.tv")) {
                icon.setImageResource(getResources().getIdentifier("ic_tv", "drawable", getPackageName()));
            } else { icon.setImageDrawable(packages.getApplicationIcon(entry.packageName)); }
        }
        catch (PackageManager.NameNotFoundException exception) {
            icon.setImageResource(android.R.drawable.ic_menu_view);
        }
        tile.addView(icon, new LinearLayout.LayoutParams(dp(compact ? 42 : 60), dp(compact ? 42 : 60)));
        TextView label = text(entry.name, compact ? 16 : 20, Color.WHITE);
        label.setGravity(Gravity.CENTER);
        label.setSingleLine(true);
        label.setEllipsize(android.text.TextUtils.TruncateAt.END);
        LinearLayout.LayoutParams labelParams = new LinearLayout.LayoutParams(-1, -2);
        labelParams.topMargin = dp(12);
        tile.addView(label, labelParams);
        tile.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View view) { launch(entry); }
        });
        return tile;
    }
    private void buildHome() {
        FrameLayout root = new FrameLayout(this);
        root.addView(new View(this) {
            private final Paint paint = new Paint();
            @Override protected void onDraw(Canvas canvas) {
                canvas.drawColor(0xff070b13);
                paint.setShader(new RadialGradient(getWidth() * .22f, getHeight() * .30f,
                        Math.max(1, getWidth() * .65f), new int[]{0xff243b58, 0xff070b13}, null, Shader.TileMode.CLAMP));
                canvas.drawRect(0, 0, getWidth(), getHeight(), paint);
            }
        }, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout page = column();
        page.setPadding(dp(42), dp(28), dp(42), dp(20));
        root.addView(page, new FrameLayout.LayoutParams(-1, -1));
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout clocks = column();
        TextClock clock = new TextClock(this);
        clock.setFormat12Hour("kk:mm"); clock.setFormat24Hour("kk:mm");
        clock.setTextColor(Color.WHITE); clock.setTextSize(40);
        clock.setTypeface(Typeface.create("sans-serif-thin", Typeface.NORMAL));
        clocks.addView(clock);
        TextClock date = new TextClock(this);
        date.setFormat12Hour("M月d日 EEEE"); date.setFormat24Hour("M月d日 EEEE");
        date.setTextColor(0xffa7b8cf); date.setTextSize(14);
        clocks.addView(date);
        header.addView(clocks, new LinearLayout.LayoutParams(0, -2, 1));
        addAction(header, action("全部应用", new Runnable() { @Override public void run() { showApps(); } }));
        addAction(header, action("信号源", new Runnable() { @Override public void run() {
            launch(component("信号源", "", "com.tcl.tv", "com.tcl.insrc.InSrcActivity"));
        } }));
        addAction(header, action("设置", new Runnable() { @Override public void run() {
            launch(component("设置", "", "com.tcl.mstar.settings", "com.tcl.mstar.settings.TclSettings"));
        } }));
        addAction(header, action("原厂桌面", new Runnable() { @Override public void run() { launch(stock()); } }));
        page.addView(header, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout hero = column();
        hero.setGravity(Gravity.CENTER_VERTICAL);
        hero.addView(text("我的电视", 16, 0xffa6b7ce));
        title = text("机顶盒 · HDMI1", 46, Color.WHITE);
        subtitle = text("观看机顶盒节目，无需在电视上搜台", 18, 0xffaabbd0);
        hero.addView(title); hero.addView(subtitle);
        page.addView(hero, new LinearLayout.LayoutParams(-1, 0, 1));
        page.addView(text("常用应用", 16, 0xffb2c1d6));
        LinearLayout dock = new LinearLayout(this);
        Entry[] entries = new Entry[]{television(),
                app("腾讯视频", "打开现有腾讯视频应用", "com.ktcp.video"),
                app("奇异果", "打开现有奇异果应用", "com.tcl.qiyiguo"),
                app("优酷", "打开现有优酷应用", "com.cibn.tv")};
        View first = null;
        for (Entry entry : entries) {
            View card = tile(entry, false);
            if (first == null) first = card;
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(146), 1);
            params.setMargins(dp(7), dp(16), dp(7), dp(14));
            dock.addView(card, params);
        }
        page.addView(dock, new LinearLayout.LayoutParams(-1, -2));
        TextView hint = text("方向键选择  ·  确认键打开  ·  返回键回到原厂桌面", 13, 0xff8f9fb7);
        hint.setGravity(Gravity.CENTER);
        page.addView(hint, new LinearLayout.LayoutParams(-1, -2));
        setContentView(root);
        if (first != null) first.requestFocus();
    }
    private List<Entry> loadApps() {
        Intent query = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> activities = packages.queryIntentActivities(query, 0);
        ArrayList<Entry> result = new ArrayList<Entry>();
        HashSet<String> seen = new HashSet<String>();
        for (ResolveInfo info : activities) {
            String name = info.activityInfo.packageName;
            String lower = name.toLowerCase(Locale.US);
            String activity = info.activityInfo.name.toLowerCase(Locale.US);
            if (!info.activityInfo.exported || !info.activityInfo.enabled || !info.activityInfo.applicationInfo.enabled ||
                    activity.contains("factory") || activity.contains("production") || activity.contains("facmenu") ||
                    name.equals("com.tcl.android.SystemDemo")) continue;
            if (name.equals(getPackageName()) || name.equals("com.tcl.cyberui") ||
                    lower.contains("factory") || lower.contains("remotetest") ||
                    lower.contains("adservice") || name.equals("com.golive.advert") || !seen.add(name)) continue;
            Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                    .setComponent(new ComponentName(name, info.activityInfo.name));
            result.add(new Entry(info.loadLabel(packages).toString(), "按确认键打开应用", intent, name));
        }
        final Collator collator = Collator.getInstance(Locale.CHINA);
        Collections.sort(result, new Comparator<Entry>() {
            @Override public int compare(Entry left, Entry right) { return collator.compare(left.name, right.name); }
        });
        return result;
    }
    private void showApps() {
        if (drawer != null && drawer.isShowing()) return;
        drawer = new Dialog(this);
        drawer.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout page = column(); page.setPadding(dp(32), dp(24), dp(32), dp(24));
        page.setBackgroundColor(0xff090f1b);
        LinearLayout header = new LinearLayout(this); header.setGravity(Gravity.CENTER_VERTICAL);
        header.addView(text("全部应用", 28, Color.WHITE), new LinearLayout.LayoutParams(0, -2, 1));
        TextView close = action("返回首页", new Runnable() { @Override public void run() { drawer.dismiss(); } });
        header.addView(close);
        page.addView(header, new LinearLayout.LayoutParams(-1, -2));
        ScrollView scroll = new ScrollView(this); scroll.setFillViewport(true);
        LinearLayout grid = column(); grid.setPadding(0, dp(16), 0, 0);
        List<Entry> entries = loadApps();
        View first = null;
        for (int offset = 0; offset < entries.size(); offset += 4) {
            LinearLayout row = new LinearLayout(this);
            for (int column = 0; column < 4; column++) {
                int index = offset + column;
                View card = index < entries.size() ? tile(entries.get(index), true) : new View(this);
                if (first == null && index < entries.size()) first = card;
                LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(112), 1);
                params.setMargins(dp(7), dp(7), dp(7), dp(7)); row.addView(card, params);
            }
            grid.addView(row, new LinearLayout.LayoutParams(-1, -2));
        }
        if (entries.isEmpty()) grid.addView(text("暂无可打开的应用，请返回原厂桌面。", 20, Color.WHITE));
        scroll.addView(grid); page.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        drawer.setContentView(page); drawer.show();
        drawer.getWindow().setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);
        if (first != null) first.requestFocus(); else close.requestFocus();
    }
    @Override public void onBackPressed() { launch(stock()); }
    @Override protected void onResume() {
        super.onResume();
        // Keep the OEM switch ordered with lifecycle callbacks and remote launches.
        useApplicationInput();
    }
    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        useApplicationInput();
        if (drawer != null && drawer.isShowing()) drawer.dismiss();
    }
    @Override protected void onDestroy() {
        if (drawer != null && drawer.isShowing()) drawer.dismiss();
        super.onDestroy();
    }
}
