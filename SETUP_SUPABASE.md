# Supabase 云端接入说明

系统已经内置当前 Supabase 项目连接信息。普通家长和学生打开网站后只需要注册、登录，不需要填写 Project URL、Publishable key 或 anon public key。

在线地址：

```text
https://15279676722.github.io/ganxue-danzhao-2027/
```

## 普通用户怎么用

### 1. 注册家长

1. 打开网站。
2. 选择 **家长端**。
3. 输入邮箱和至少 6 位密码。
4. 点击 **注册新账号**。
5. 系统会自动创建家庭组和 6 位家庭邀请码。

### 2. 家长直接创建孩子账号

家长注册并进入系统后：

1. 点击左侧 **学习情况**。
2. 在 **直接创建孩子账号** 中填写：
   - 孩子姓名；
   - 孩子邮箱；
   - 孩子初始密码。
3. 点击 **创建孩子账号**。
4. 把孩子邮箱和密码发给孩子。
5. 孩子在自己的手机或电脑打开网站，选择 **孩子端**，点击 **登录已有账号** 即可。

孩子也可以自己注册：选择 **孩子端** 后填写家长提供的 6 位家庭邀请码。

### 3. 忘记密码

1. 在登录页邮箱框填写账号邮箱。
2. 点击 **忘记密码**。
3. 查收邮件并点击邮件按钮。
4. 在网页中输入新密码并保存。

Supabase 后台已配置：

- Site URL：`https://15279676722.github.io/ganxue-danzhao-2027/`
- Redirect URLs：`https://15279676722.github.io/ganxue-danzhao-2027/**`

如果以前收到的重置邮件打开是 404，那是旧邮件使用了旧跳转地址；重新点击一次“忘记密码”获取新邮件即可。

## 公共题库和私人题库

- **公共题库**：所有家庭共用，目前 80 道官方题。只有管理员能新增、修改、删除；普通家长只能看到“只读”。
- **私人题库**：属于某个家庭，家长在“题库管理”里新增题目、或在“题库更新”里批量导入 JSON，都会自动进入自己的私人题库；家庭里的孩子能看到公共题加自家私人题，看不到其他家庭的私人题。
- 家长在“题库更新”页点 **把题目同步到我的私人题库** 即可把本机题目同步到云端；管理员额外有 **发布/更新公共题库** 按钮。

### 查看或更换管理员

第一个注册的家长在执行 `supabase-private-banks.sql` 时已被自动设为管理员。以后要更换或追加管理员，在 SQL Editor 执行（把邮箱换成家长注册邮箱）：

```sql
update public.profiles set is_admin = true
where id = (select id from auth.users where email = '家长邮箱@example.com');
```

取消管理员：

```sql
update public.profiles set is_admin = false
where id = (select id from auth.users where email = '家长邮箱@example.com');
```

## 管理员换 Supabase 项目时才需要做

如果以后更换 Supabase 项目，才需要执行下面步骤。

1. 创建免费 Supabase 项目。
2. 在 **Authentication → Sign In / Providers → Email** 中：
   - 启用 Email；
   - 试用阶段关闭 Confirm email。
3. 在 **Authentication → URL Configuration** 中配置 GitHub Pages Site URL 和 Redirect URL。
4. 在 SQL Editor 依次执行：
   - `supabase-schema.sql`（已包含公共/私人题库的字段和权限）；
   - `supabase-seed-questions.sql`；
   - 注册第一个家长账号后，如需让该账号管理公共题库，执行上面“查看或更换管理员”的 SQL。
   - 注意：`supabase-private-banks.sql` 只用于 2026-10-24 之前建好的旧库升级，新库不要执行。
5. 修改 `index.html` 中的内置配置：

```js
const SUPABASE_CONFIG=Object.freeze({
  url:'https://你的项目ID.supabase.co',
  anonKey:'sb_publishable_...'
});
```

Publishable key / anon public key 是浏览器端公开密钥，数据库安全由 RLS 行级权限和家庭组策略控制。绝不能把 `service_role`、`sb_secret_...` 或数据库密码写入前端。 
