import Foundation

struct DemoParagraph: Identifiable, Equatable, Sendable {
    var id: String { en }
    let en: String
    let zh: String
}

struct DemoChapter: Identifiable, Equatable, Sendable {
    var id: String { n }
    let n: String
    let title: String
    let paras: [DemoParagraph]
}

enum DemoData {
    static let bookTitle = "The Great Gatsby"
    static let author = "F. Scott Fitzgerald"

    static let chapters: [DemoChapter] = [
        DemoChapter(
            n: "I",
            title: "In my younger and more vulnerable years",
            paras: [
                DemoParagraph(
                    en: "In my younger and more vulnerable years my father gave me some advice that I’ve been turning over in my mind ever since.",
                    zh: "在我年纪尚轻、阅历未深的那些年里，父亲给过我一句忠告，我至今仍反复琢磨。"
                ),
                DemoParagraph(
                    en: "“Whenever you feel like criticizing any one,” he told me, “just remember that all the people in this world haven’t had the advantages that you’ve had.”",
                    zh: "\"每当你想批评别人的时候，\"他对我说，\"记住，这世上并非所有人都拥有过你所拥有的那些条件。\""
                ),
                DemoParagraph(
                    en: "He didn’t say any more, but we’ve always been unusually communicative in a reserved way, and I understood that he meant a great deal more than that.",
                    zh: "他没再多说什么，但我们父子之间向来不必多言便能心领神会，我明白他这话的分量远不止字面那么简单。"
                ),
                DemoParagraph(
                    en: "In consequence, I’m inclined to reserve all judgments, a habit that has opened up many curious natures to me and also made me the victim of not a few veteran bores.",
                    zh: "因此，我习惯了对一切都不轻易下判断，这种习惯让我得以窥见许多有趣的灵魂，也让我成了不少老资格闲谈者的牺牲品。"
                ),
                DemoParagraph(
                    en: "The abnormal mind is quick to detect and attach itself to this quality when it appears in a normal person, and so it came about that in college I was unjustly accused of being a politician, because I was privy to the secret griefs of wild, unknown men.",
                    zh: "怪人善于嗅出常人身上这种品质并迅速亲近过来，于是大学时代我便被人冤枉地称作\"政客\"，只因我成了那些素昧平生的狂人秘密苦楚的倾诉对象。"
                ),
                DemoParagraph(
                    en: "Most of the confidences were unsought, frequently I have feigned sleep, preoccupation, or a hostile levity when I realized by some unmistakable sign that an intimate revelation was quivering on the horizon.",
                    zh: "这些倾诉大多并非我所求，我常常装睡、装作出神，或摆出敌意的玩世不恭，只要某些不容错认的迹象暗示一场私密的剖白正在地平线上颤抖待发。"
                ),
            ]
        ),
        DemoChapter(
            n: "II",
            title: "About half way between West Egg and New York",
            paras: [
                DemoParagraph(
                    en: "About half way between West Egg and New York the motor road hastily joins the railroad and runs beside it for a quarter of a mile, so as to shrink away from a certain desolate area of land.",
                    zh: "从西卵到纽约的中途，公路急匆匆地与铁路并行了大约四分之一英里，仿佛想要避开一片荒凉的土地。"
                ),
                DemoParagraph(
                    en: "This is a valley of ashes, a fantastic farm where ashes grow like wheat into ridges and hills and grotesque gardens.",
                    zh: "那是一片灰烬的山谷，一个荒诞的农场，灰烬如麦子般成行成垄、堆成小山和怪诞的花园。"
                ),
                DemoParagraph(
                    en: "Occasionally a line of gray cars crawls along an invisible track, gives out a ghastly creak and comes to rest, and immediately the ash-gray men swarm up with leaden spades and stir up an impenetrable cloud which screens their obscure operations from your sight.",
                    zh: "偶尔一列灰色车厢沿着看不见的轨道缓缓爬行，发出阴森的吱嘎声后停下，立刻有一群灰扑扑的人挥着铅锤般的铁锹蜂拥而上，扬起一团遮天蔽日的尘雾，把他们暧昧的劳作从你视线里抹去。"
                ),
                DemoParagraph(
                    en: "But above the gray land and the spasms of bleak dust which drift endlessly over it, you perceive, after a moment, the eyes of Doctor T. J. Eckleburg.",
                    zh: "可是在这片灰色的土地之上、在那永无止境的阵阵阴郁尘雾之上，过一会儿你就会看见，T. J. 埃克尔堡医生的那双眼睛。"
                ),
            ]
        ),
        DemoChapter(
            n: "III",
            title: "There was music from my neighbor’s house",
            paras: [
                DemoParagraph(
                    en: "There was music from my neighbor’s house through the summer nights. In his blue gardens men and girls came and went like moths among the whisperings and the champagne and the stars.",
                    zh: "整个夏夜，邻家始终乐声不息。在他蓝色的花园里，男男女女如飞蛾般来去，穿行于低语、香槟和繁星之间。"
                ),
                DemoParagraph(
                    en: "At high tide in the afternoon I watched his guests diving from the tower of his raft, or taking the sun on the hot sand of his beach while his two motor-boats slit the waters of the Sound, drawing aquaplanes over cataracts of foam.",
                    zh: "下午涨潮时分，我看着他的客人们从他那筏子上的跳台一头扎进水里，或在他海滩滚烫的沙上晒太阳，而他那两艘汽艇划开海湾的水面，拖着滑水板在浪花的瀑布上奔驰。"
                ),
                DemoParagraph(
                    en: "On week-ends his Rolls-Royce became an omnibus, bearing parties to and from the city, between nine in the morning and long past midnight, while his station wagon scampered like a brisk yellow bug to meet all trains.",
                    zh: "周末时，他的劳斯莱斯成了一辆公共汽车，从清晨九点一直到午夜过后，载着宾客往返于市区，而他那辆旅行车则像一只敏捷的黄色甲虫一样，飞奔去接每一班列车。"
                ),
                DemoParagraph(
                    en: "And on Mondays eight servants, including an extra gardener, toiled all day with mops and scrubbing-brushes and hammers and garden-shears, repairing the ravages of the night before.",
                    zh: "到了星期一，八个仆人，还有一位临时雇来的园丁，整天挥舞着拖把、刷子、锤子和园艺剪，修补前一夜留下的种种狼藉。"
                ),
                DemoParagraph(
                    en: "Every Friday five crates of oranges and lemons arrived from a fruiterer in New York, every Monday these same oranges and lemons left his back door in a pyramid of pulpless halves.",
                    zh: "每个星期五，五箱橙子和柠檬从纽约的一家水果商那里送来；每个星期一，这同一批橙子和柠檬便从后门离开他家，化作一座座掏空果肉的半壳金字塔。"
                ),
                DemoParagraph(
                    en: "There was a machine in the kitchen which could extract the juice of two hundred oranges in half an hour, if a little button was pressed two hundred times by a butler’s thumb.",
                    zh: "厨房里有一台机器，只要管家用拇指按下那个小按钮两百次，就能在半小时内榨出两百只橙子的汁。"
                ),
                DemoParagraph(
                    en: "At least once a fortnight a corps of caterers came down with several hundred feet of canvas and enough colored lights to make a Christmas tree of Gatsby’s enormous garden.",
                    zh: "至少每两周一次，一队办酒席的人马运来几百英尺的帆布和足够多的彩灯，把盖茨比那硕大的花园装点得像一棵圣诞树。"
                ),
                DemoParagraph(
                    en: "On buffet tables, garnished with glistening hors-d’oeuvre, spiced baked hams crowded against salads of harlequin designs and pastry pigs and turkeys bewitched to a dark gold.",
                    zh: "自助餐桌上，光亮可鉴的开胃小点旁边，香料烤火腿挤着色彩斑斓的拼盘沙拉，旁边还有变戏法般烤成深金色的酥皮乳猪和火鸡。"
                ),
            ]
        ),
        DemoChapter(
            n: "IV",
            title: "On Sunday morning",
            paras: [
                DemoParagraph(
                    en: "On Sunday morning while church bells rang in the villages alongshore, the world and its mistress returned to Gatsby’s house and twinkled hilariously on his lawn.",
                    zh: "星期天早晨，沿海村庄教堂的钟声响起，世界和它的情妇又回到了盖茨比的家中，在他的草坪上闪烁着喧闹的光辉。"
                ),
                DemoParagraph(
                    en: "“He’s a bootlegger,” said the young ladies, moving somewhere between his cocktails and his flowers. “One time he killed a man who had found out that he was nephew to von Hindenburg and second cousin to the devil.”",
                    zh: "\"他是个走私贩子，\"小姐们这样说，一边在他的鸡尾酒和他的花束之间穿梭。\"有一次他杀了个人，那人发现他是兴登堡的外甥，又是魔鬼的表亲。\""
                ),
                DemoParagraph(
                    en: "“Reach me a rose, honey, and pour me a last drop into that there crystal glass.”",
                    zh: "\"给我一朵玫瑰，亲爱的，再往那只水晶杯里给我倒最后一滴。\""
                ),
                DemoParagraph(
                    en: "I have been drunk just twice in my life, and the second time was that afternoon; so everything that happened has a dim, hazy cast over it, although until after eight o’clock the apartment was full of cheerful sun.",
                    zh: "我这辈子只醉过两次，第二次便是那个下午；所以那天发生的一切都罩着一层朦胧暗淡的色调，尽管八点之前，公寓里还满是欢快的阳光。"
                ),
            ]
        ),
        DemoChapter(
            n: "V",
            title: "When I came home to West Egg",
            paras: [
                DemoParagraph(
                    en: "When I came home to West Egg that night I was afraid for a moment that my house was on fire.",
                    zh: "那天夜里我回到西卵时，恍惚之间以为自己的房子着了火。"
                ),
                DemoParagraph(
                    en: "Two o’clock and the whole corner of the peninsula was blazing with light, which fell unreal on the shrubbery and made thin elongating glints upon the roadside wires.",
                    zh: "凌晨两点，半岛的整个一角灯火通明，光线落在灌木丛上显得虚幻不真，又在路边的电线上拉出细细的、长长的反光。"
                ),
                DemoParagraph(
                    en: "Turning a corner, I saw that it was Gatsby’s house, lit from tower to cellar.",
                    zh: "拐过转角，我才看出是盖茨比的房子，从塔楼到地窖，从上到下灯火辉煌。"
                ),
            ]
        ),
        DemoChapter(
            n: "VI",
            title: "About this time an ambitious young reporter",
            paras: [
                DemoParagraph(
                    en: "About this time an ambitious young reporter from New York arrived one morning at Gatsby’s door and asked him if he had anything to say.",
                    zh: "大约就在这时候，一位野心勃勃的纽约年轻记者一天早晨来到盖茨比门前，问他是否有什么话要说。"
                ),
                DemoParagraph(
                    en: "“Anything to say about what?” inquired Gatsby politely.",
                    zh: "\"关于什么的什么话呢？\"盖茨比客气地反问。"
                ),
                DemoParagraph(
                    en: "“Why, any statement to give out.”",
                    zh: "\"嗯，任何想发表的声明都行。\""
                ),
            ]
        ),
        DemoChapter(
            n: "VII",
            title: "It was when curiosity about Gatsby was at its highest",
            paras: [
                DemoParagraph(
                    en: "It was when curiosity about Gatsby was at its highest that the lights in his house failed to go on one Saturday night, and, as obscurely as it had begun, his career as Trimalchio was over.",
                    zh: "人们对盖茨比的好奇心达到顶点的那一阵子，他家的灯光在一个星期六的夜晚没有再亮起，就这样，他作为特里马尔奇奥的事业，如它开始时那样不动声色地落幕了。"
                ),
                DemoParagraph(
                    en: "Only gradually did I become aware that the automobiles which turned expectantly into his drive stayed for just a minute and then drove sulkily away.",
                    zh: "直到后来我才慢慢察觉，那些满怀期待驶进他车道的汽车，只停留片刻便愠怒地离开了。"
                ),
                DemoParagraph(
                    en: "Wondering if he were sick I went over to find out, an unfamiliar butler with a villainous face squinted at me suspiciously from the door.",
                    zh: "我担心他是不是病了，便过去探看，一个面目凶狠、陌生的管家从门里斜眼狐疑地打量我。"
                ),
            ]
        ),
        DemoChapter(
            n: "VIII",
            title: "I couldn’t sleep all night",
            paras: [
                DemoParagraph(
                    en: "I couldn’t sleep all night; a fog-horn was groaning incessantly on the Sound, and I tossed half-sick between grotesque reality and savage, frightening dreams.",
                    zh: "那一整夜我都没能合眼；海湾上雾号呜咽不止，我在怪诞的现实和狂暴可怖的梦境之间辗转，浑身像是病了一半。"
                ),
                DemoParagraph(
                    en: "Toward dawn I heard a taxi go up Gatsby’s drive, and immediately I jumped out of bed and began to dress, I felt that I had something to tell him, something to warn him about.",
                    zh: "快到天亮时，我听见一辆出租车驶上盖茨比的车道，便立刻跳下床穿好衣服，我感到有些事必须告诉他，有些事必须警告他。"
                ),
                DemoParagraph(
                    en: "Crossing his lawn, I saw that his front door was still open and he was leaning against a table in the hall, heavy with dejection or sleep.",
                    zh: "穿过他的草坪时，我看到他家正门还敞着，他正倚在门厅的一张桌子上，沉重得说不清是颓丧还是困倦。"
                ),
            ]
        ),
        DemoChapter(
            n: "IX",
            title: "After two years I remember",
            paras: [
                DemoParagraph(
                    en: "After two years I remember the rest of that day, and that night and the next day, only as an endless drill of police and photographers and newspaper men in and out of Gatsby’s front door.",
                    zh: "两年之后，那一天剩下的时光、那个晚上以及第二天，在我的记忆里只剩下警察、摄影师和报社记者无休止地进进出出于盖茨比家正门的喧嚣。"
                ),
                DemoParagraph(
                    en: "A rope stretched across the main gate and a policeman by it kept out the curious, but little boys soon discovered that they could enter through my yard, and there were always a few of them clustered open-mouthed about the pool.",
                    zh: "一道绳索横在正门上，一名警察守在旁边挡住了好奇的人群，但孩子们很快就发现从我的院子可以进去，于是总有几个孩子张着嘴聚在游泳池边。"
                ),
                DemoParagraph(
                    en: "Someone with a positive manner, perhaps a detective, used the expression “madman” as he bent over Hennessy’s body that afternoon; and the authority of his voice set the key for the newspaper reports next morning.",
                    zh: "那天下午有个语气笃定的人，也许是位侦探，俯身查看亨尼西的尸体时用了\"疯子\"这个词；他那权威的口吻为第二天早晨的报纸报道定下了基调。"
                ),
            ]
        ),
    ]
}
