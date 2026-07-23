# About me

↓↓↓↓↓↓↓↓↓↓↓↓↓↓2026年7月20日↓↓↓↓↓↓↓↓↓↓↓↓↓↓  

可可五笔官网： https://keke.kim/  

提示：
* 使用时，只需要把全部文件拷贝到各RIME前端的用户文件夹（名字都叫“ Rime”，也可以先清空再复制），重新部署即可使用
* 不同平台Rime前端名称：windows：小狼毫；MacOS：鼠须管；iOS：iRime；安卓：同文；Linux：ibus-rime
* 建议使用windows版本的可可五笔生成自己的词库（支持只导入词条，能自动生成编码）导出后复制到 keke_wubi_XX_user.dict.yaml 重新部署即可
* 关于在线加词，这完全是个鸡肋的功能，自己的词库慢慢维护，能导入即可
* 关于跨平台，因为各平台功能有差异，比如在手机端不支持左右shift，所以RIME移植版的可可不支持英文词典
* 关于临时拼音，可可五笔是专业的五笔软件，临时拼音（z键引导）只支持全拼，只是防止用户忘记字怎么写时临时应急，RIME平台移植的可可五笔也不再支持五笔反查
* 文件结构如下：

```tree
    Rime/                                      # 所有平台都是这个配置目录
        ├─ default.custom.yaml                 # 全局补丁
        ├─ lua/                                # lua文件夹
           └─ command_translator.lua           # 命令翻译器，支持输入：rmb888.88 输出：捌佰捌拾捌元捌角捌分；还支持直接输入 help、time、date、week等
           └─ rime.lua                         #全局注册lua
        ├─ img/                                # windows平台有效的图标
           └─ en.ico                           # 英文状态图标
           └─ zh.ico                           # 中文状态图标
        三套输入方案
        ├─ keke_wubi_86.schema.yaml            #86版五笔方案
        ├─ keke_wubi_98.schema.yaml            #98版五笔方案
        ├─ keke_wubi_nc.schema.yaml            #新世纪版五笔方案
        可可五笔86版
        ├─ keke_wubi_86_common.dict.yaml       #86版五笔常用字
        ├─ keke_wubi_86_system.dict.yaml       #86版五笔系统字词
        ├─ keke_wubi_86_rare.dict.yaml         #86版五笔生僻字
        可可五笔98版
        ├─ keke_wubi_98_common.dict.yaml        #98版五笔常用字
        ├─ keke_wubi_98_system.dict.yaml        #98版五笔系统字词
        ├─ keke_wubi_98_rare.dict.yaml          #98版五笔生僻字
        可可五笔新世纪版
        ├─ keke_wubi_nc_common.dict.yaml        #新世纪版五笔常用字
        ├─ keke_wubi_nc_system.dict.yaml        #新世纪版五笔系统字词
        ├─ keke_wubi_nc_rare.dict.yaml          #新世纪版五笔生僻字
        用户自己的词库（建议通过以下文件维护自己的词库，不要动其它文件）
        ├─ keke_wubi_86_user.dict.yaml
        ├─ keke_wubi_98_user.dict.yaml
        ├─ keke_wubi_nc_user.dict.yaml
        全局词库
        └─ keke_wubi_global_symbols.dict.yaml       # 可可特殊符号
        └─ keke_wubi_global_pinyin.dict.yaml        # 可可临时拼音词库，先按字母 z 进入临时拼音模式
