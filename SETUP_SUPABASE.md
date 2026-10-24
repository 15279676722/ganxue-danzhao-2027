# Supabase 云端接入步骤

本项目已经内置 Supabase 接入代码。未配置云端时，网站仍使用原来的本机演示模式；配置后，账号、题库、做题记录和错题本会走云端数据库。

## 一、创建免费 Supabase 项目

1. 打开 <https://supabase.com/>，用 GitHub 账号登录。
2. 点击 **New project**。
3. 建议区域选择离中国较近的 **Southeast Asia / Singapore**。
4. 设置数据库密码并妥善保存。数据库密码不需要填入本网站。
5. 等待项目初始化完成。

> 免费套餐足够题库、少量学生账号和学习记录试用。免费项目长期不访问可能暂停，重新访问后可恢复。

## 二、关闭邮箱验证（试用阶段建议）

默认情况下，Supabase 注册后需要点击邮件验证链接。为了让家长和孩子能立即登录：

1. 进入 **Authentication → Sign In / Providers → Email**。
2. 暂时关闭 **Confirm email**。
3. 保存。

正式使用时可以重新开启邮箱验证。

同时建议进入 **Authentication → URL Configuration**：

- Site URL 设置为：

```text
https://15279676722.github.io/ganxue-danzhao-2027/
```

- Redirect URLs 添加：

```text
https://15279676722.github.io/ganxue-danzhao-2027/**
```

## 三、执行数据库 SQL

在 Supabase 后台进入 **SQL Editor → New query**。

按顺序执行仓库中的两个文件：

1. 先执行 [`supabase-schema.sql`](./supabase-schema.sql)  
   创建家庭、账号资料、题库、做题记录、错题本和权限策略。
2. 再执行 [`supabase-seed-questions.sql`](./supabase-seed-questions.sql)  
   导入现有 80 道 2026 真实题库。

执行成功后，应能在 **Table Editor** 看到这些表：

- `families`
- `profiles`
- `questions`
- `attempts`
- `wrong_book`

## 四、在网站中填写云端配置

打开网站后：

1. 用家长演示账号进入：`parent / 123456`。
2. 进入左侧 **题库更新**。
3. 在 **Supabase 云端账号与数据库** 卡片中填写：
   - `Project URL`
   - `anon public key`
4. 点击 **保存云端配置**。
5. 退出登录，回到登录页。

Project URL 和公钥按新版 Supabase 后台获取：

1. 进入项目后，点击页面顶部的 **Connect**。
2. 在连接弹窗中复制 **Project URL**（形如 `https://xxxxx.supabase.co`）和 **Publishable key**（形如 `sb_publishable_...`）。
3. 如果项目仍显示旧版密钥，进入 **Project Settings → API Keys → Legacy API Keys**，复制 **anon / public** 密钥（通常以 `eyJ` 开头）。

注意：

- `Publishable key` 和旧版 `anon public key` 都是给浏览器使用的公开客户端密钥，可以暴露在前端。
- 数据库安全由 RLS 行级权限策略控制。
- **绝对不要把 `service_role key` 填进网页，也不要发给任何人。**

## 五、注册家长和孩子

### 家长

1. 登录页选择 **家长端**。
2. 输入邮箱和至少 6 位密码。
3. 家庭码留空。
4. 点击 **注册账号**。

系统会自动创建一个家庭组和 6 位家庭码。

家长登录后进入 **学习情况**，可以看到“家庭邀请码”。

### 孩子

1. 在孩子的电脑或手机浏览器打开同一个网站。
2. 在登录页展开“首次使用：配置云端连接”，填写同一套 `Project URL` 和 `anon public key`（每台设备只需保存一次）。
3. 登录页选择 **孩子端**。
4. 输入孩子自己的邮箱和密码。
5. 填写家长提供的 6 位家庭码。
6. 点击 **注册账号**。

孩子做题后，家长会自动看到云端统计、做题记录和错题情况。

## 六、题库维护

因为已经执行了种子 SQL，云端会有 80 道题。

如果以后在网页中新增、修改或导入题库：

- 必须使用 **家长云端账号** 操作；
- 网页会自动同步到 Supabase `questions` 表；
- 孩子重新打开网页时会读取云端题库。

也可以在“题库更新”页点击 **把当前题库发布到云端**，将当前浏览器里的题库批量上传。

## 七、数据和权限说明

- 孩子只能写入自己的 `attempts` 和 `wrong_book`。
- 家长只能查看同一家庭组孩子的数据。
- 家长可以维护题库。
- 孩子不能修改题库。
- 不同家庭之间无法读取对方数据。
- 本地备份和恢复功能仍保留，可在网络异常时临时使用。

## 八、常见问题

### 注册时提示孩子必须填写家庭码

先注册家长账号。家长注册时家庭码留空，注册成功后在“学习情况”页查看家庭码。

### 注册后不能登录

检查是否开启了邮箱验证。若开启，需要先点击邮件里的验证链接；试用阶段也可以按第二步关闭验证。

### 页面提示 SDK 加载超时

通常是当前网络访问 jsDelivr 或 Supabase 较慢。系统会自动降级为本机模式。正式在国内长期使用前，需要测试 Supabase 访问速度。

### 家长看不到孩子数据

确认：

- 孩子注册时填写的家庭码正确；
- 家长和孩子在同一家庭组；
- 孩子已经完成至少一次答题；
- 当前登录的是云端账号，而不是 `parent / 123456` 演示账号。
