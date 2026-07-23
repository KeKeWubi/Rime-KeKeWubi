# About me

↓↓↓↓↓↓↓↓↓↓↓↓↓↓2026年7月20日↓↓↓↓↓↓↓↓↓↓↓↓↓↓  

可可五笔官网： https://keke.kim/  

提示：
* 使用时，只需要把全部文件拷贝到各RIME前端的用户文件夹（名字都叫“ Rime”），重新部署即可使用可可
* 不同平台Rime前端名称：windows：小狼毫；MacOS：鼠须管；iOS：iRime；安卓：同文；Linux：ibus-rime
* 文件结构如下：

```tree
Rime/
├─ rime.lua                  # Lua模块全局注册
├─ default.custom.yaml       # 全局补丁
├─ lua/                      # lua文件夹
│  └─ command_translator.lua # 日期时间脚本
├─ img/                      # windows平台有效的图标
│  └─ en.ico                 # 英文状态图标
│  └─ zh.ico                 # 中文状态图标
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
全局词库
└─ keke_wubi_global_symbols.dict.yaml # 可可特殊符号
└─ keke_wubi_global_pinyin.dict.yaml  # 可可临时拼音词库
