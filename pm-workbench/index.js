/**
 * Host half of PM Workbench — intentionally minimal.
 *
 * 历史教训（务必保留这段说明，别再走回头路）：
 * 我们曾在这里用 `ctx.webServer.register(...)` 注册 `/pm-minutes/*` 宿主路由，
 * 让面板 fetch 这些路由来读钉钉 dws 数据。结果反复出问题：
 *   1) 宿主插件 apply 的调用时机不可控（例如导出 name/inject 后 cordis 直接不再调用 apply）；
 *   2) 宿主代码热加载会注销已注册路由、却不重新 apply → 面板 404；
 *   3) 每次改宿主代码都要重启 DSH 才能恢复。
 *
 * 现在的架构：**面板只读项目内的 .pm-cache 缓存文件**（经 better-sidebar 已有的
 * `/sidebar/file` 接口），缓存由本地脚本 / Agent 运行 dws 生成。于是：
 *   - 面板零宿主依赖，改客户端刷新即生效，无需重启；
 *   - 可分发给其他 PM（无个人路径、无服务器名）。
 *
 * 因此本文件**不再注册任何路由、不再持有任何 HTTP 服务**。若将来确实需要宿主能力，
 * 请先确认 DSH 提供的稳定契约，并同步更新 verify.ps1 的守卫。
 */
export function apply() {
  // 有意为空：宿主半边不需要做任何事。
}
