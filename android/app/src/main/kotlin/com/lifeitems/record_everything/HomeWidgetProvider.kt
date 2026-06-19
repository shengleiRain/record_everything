package com.lifeitems.record_everything

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_home).apply {
                // 日期
                setTextViewText(
                    R.id.widget_date,
                    widgetData.getString("widget_date", "📅 --") ?: "📅 --"
                )

                // 待办概览
                val todayCount = widgetData.getInt("widget_today_count", 0)
                val overdueCount = widgetData.getInt("widget_overdue_count", 0)
                val summary = buildString {
                    append("今日待办 $todayCount 项")
                    if (overdueCount > 0) append("    已逾期 $overdueCount 项")
                }
                setTextViewText(R.id.widget_summary, summary)

                // 待办条目
                val itemsJson = widgetData.getString("widget_items", "[]") ?: "[]"
                try {
                    val items = org.json.JSONArray(itemsJson)
                    val itemViews = listOf(
                        R.id.widget_item_1,
                        R.id.widget_item_2,
                        R.id.widget_item_3
                    )
                    for (i in 0 until minOf(items.length(), 3)) {
                        val item = items.getJSONObject(i)
                        val title = item.getString("title")
                        val isOverdue = item.getBoolean("isOverdue")
                        val prefix = if (isOverdue) "⚠️ " else "  · "
                        setTextViewText(itemViews[i], "$prefix$title")
                        setViewVisibility(itemViews[i], View.VISIBLE)
                    }
                    // 隐藏多余的条目
                    for (i in items.length() until 3) {
                        setViewVisibility(itemViews[i], View.GONE)
                    }
                } catch (_: Exception) {}

                // 收支
                val income = widgetData.getString("widget_monthly_income", "--") ?: "--"
                val expense = widgetData.getString("widget_monthly_expense", "--") ?: "--"
                setTextViewText(R.id.widget_finance, "本月：收入 $income  支出 $expense")

                // 点击整个 Widget → 打开首页
                val homeIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("lifeitems://home")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val homePending = PendingIntent.getActivity(
                    context, 0, homeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_date, homePending)
                setOnClickPendingIntent(R.id.widget_summary, homePending)

                // 点击 [+记账] → 打开智能输入
                val addIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("lifeitems://smart-entry/input")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val addPending = PendingIntent.getActivity(
                    context, 1, addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_add_btn, addPending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
