# About me

↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓2026年7月20日↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓  

可可五笔官网： https://keke.kim/  

设计结构如下：  

```tree
Rime/
├─ rime.lua                  # Lua模块全局注册
├─ default.custom.yaml       # 全局补丁
├─ lua/                      # lua文件夹
│  └─ command_translator.lua # 日期时间脚本
三套输入方案
├─ keke_wubi_86.schema.yaml
├─ keke_wubi_98.schema.yaml
├─ keke_wubi_nc.schema.yaml
可可五笔86版
├─ keke_wubi_86_common.dict.yaml
├─ keke_wubi_86_system.dict.yaml
├─ keke_wubi_86_rare.dict.yaml
可可五笔98版
├─ keke_wubi_98_common.dict.yaml
├─ keke_wubi_98_system.dict.yaml
├─ keke_wubi_98_rare.dict.yaml
可可五笔新世纪版
├─ keke_wubi_nc_common.dict.yaml
├─ keke_wubi_nc_system.dict.yaml
├─ keke_wubi_nc_rare.dict.yaml
全局符号词库（待改进）
└─ keke_wubi_global_symbols.dict.yaml
