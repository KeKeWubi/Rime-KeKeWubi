### About me

↓↓↓↓↓↓↓↓↓↓↓↓↓↓2026年7月20日↓↓↓↓↓↓↓↓↓↓↓↓↓↓  

可可五笔官网： https://keke.kim/  

提示：
* 使用时，只需要把全部文件拷贝到各RIME前端的“用户文件夹”（所有可用平台都叫 “Rime”），重新部署即可使用。 
* 不同平台Rime前端：（windows：小狼毫）；（MacOS：鼠须管）；（iOS：Hamster 仓输入法）；（安卓：同文）；（Linux：ibus-rime）。
* 按 Ctrl+0 切换三种五笔方案。
* 用户修改方案文件 keke_wubi_XX.schema.yaml 这一个文件里的配置项即可实现不同的功能，能修改的地方都加了备注，修改完要重新部署。
* 建议使用windows版本的可可五笔生成自己的词库（支持只导入词条，能自动生成编码）导出后复制到 keke_wubi_XX_user.dict.yaml 重新部署即可。
* 关于在线加词，自己的词库慢慢维护，能导入即可。
* 关于跨平台，因为各平台功能有差异，比如在手机端不支持左右shift，所以RIME移植版的可可“不支持”英文词典。
* 关于临时拼音，可可五笔是专业的五笔软件，临时拼音（z键引导）只支持全拼，防止用户忘记字怎么写时临时应急，RIME平台移植的可可五笔“不支持”五笔反查。
* 关于性能：可可追求极致。以万能z模糊查询为例，没有这个功能，可可使用内存6M左右；增加这个功能但不使用（“禁用万能Z”状态）内存使用8M，使用这个功能但没有按z键时内存12M，
  唯一的情况是按z键瞬间到达36M，这足以使一个有内存洁癖的程序员心痛不已。为解决这个问题，特提供一个“无万能z键的极省内存版本”的分支供用户下载，此分支“不再”维护。
  main版本都包含万能z键，但默认“禁用”，需要这个功能按 Ctrl+0 打开，注意：打开此功能只对当前应用程序有效。万能Z键“支持”五笔反查。
* 文件结构及主要功能解释如下：

```tree
Rime/									# 所有可用平台都是这个配置目录
├─ default.custom.yaml					# 全局补丁
├─ lua/									# lua脚本目录（新Rime版本的脚本都放在此处）
	└─ keke_wubi_command_translator.lua	# 命令翻译器，输入 rmb888.88 输出 捌佰捌拾捌元捌角捌分；或 help、time、date、week等
	└─ keke_wubi_fuzzy_z.lua			# 万能键 Z 脚本。性能为王的原则，所以：一，默认禁用，Ctrl+0 打开；二，仅查寻五笔单字
	└─ keke_wubi_char_prior.lua			#单字在前脚本，修选框里“单字在前”
	└─ keke_wubi_char_only.lua			#仅单字脚本，修选框里“仅单字”，单字派用这个功能
	└─ keke_wubi_length_filter.lua		#设置第几码开始提示后续编码的脚本
三套输入方案
├─ keke_wubi_86.schema.yaml				#86版五笔方案
├─ keke_wubi_98.schema.yaml				#98版五笔方案
├─ keke_wubi_nc.schema.yaml				#新世纪版五笔方案
可可五笔86版词典
├─ keke_wubi_86_common.dict.yaml		#86版五笔常用字
├─ keke_wubi_86_system.dict.yaml		#86版五笔系统字词
├─ keke_wubi_86_rare.dict.yaml			#86版五笔生僻字
可可五笔98版词典
├─ keke_wubi_98_common.dict.yaml		#98版五笔常用字
├─ keke_wubi_98_system.dict.yaml		#98版五笔系统字词
├─ keke_wubi_98_rare.dict.yaml			#98版五笔生僻字
可可五笔新世纪版词典
├─ keke_wubi_nc_common.dict.yaml		#新世纪版五笔常用字
├─ keke_wubi_nc_system.dict.yaml		#新世纪版五笔系统字词
├─ keke_wubi_nc_rare.dict.yaml			#新世纪版五笔生僻字
用户自己的词库（建议通过以下文件维护自己的词库，不要动其它文件）
├─ keke_wubi_86_user.dict.yaml
├─ keke_wubi_98_user.dict.yaml
├─ keke_wubi_nc_user.dict.yaml
全局词库
└─ keke_wubi_global_symbols.dict.yaml	#可可特殊符号，z引导，如：zbd：常用标点；zys：圆圈数字等等
└─ keke_wubi_global_pinyin.dict.yaml	#可可临时拼音，z引导，如：zkeke，输出 可可
脚本和图标
└─ rime.lua								#早期Rime需要全局注册的脚本通过本文件注册（现已弃用）
├─ img/									# 备用图标（目前仅windows平台可用）
	└─ en.ico							# 英文状态图标
	└─ zh.ico							# 中文状态图标
	└─ en.png							# 英文状态图标
	└─ zh.png							# 中文状态图标
