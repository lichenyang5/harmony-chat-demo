import { NextResponse } from 'next/server'

type ContentType = 'prompt' | 'assistant'

interface Product {
  id: string
  name: string
  price: number
  originalPrice: number
  desc: string
  image: string
  tag: string
  rating: number
  sales: number
  stock: number
  coverHeight: number
  contentType: ContentType
}

interface ProductSeed {
  id: string
  name: string
  desc: string
  tag: string
  rating: number
  sales: number
  coverHeight: number
  contentType: ContentType
}

/**
 * 统一补齐 Demo 内容的公共字段，保证所有卡片继续复用原来的本地图片。
 * 首页已转为免费 AI 灵感流，价格字段只为兼容原详情与购物车数据结构。
 */
function createProduct(seed: ProductSeed): Product {
  return {
    ...seed,
    price: 0,
    originalPrice: 0,
    image: 'images/1.png',
    stock: 999
  }
}

const MOCK_PRODUCTS: Product[] = [
  createProduct({ id: 'ai-001', name: '小红书爆款文案助手', desc: '输入产品卖点与目标人群，生成标题、正文、话题标签和多种语气版本。', tag: '热门', rating: 4.9, sales: 8421, coverHeight: 132, contentType: 'assistant' }),
  createProduct({ id: 'ai-002', name: '把复杂知识讲给小学生', desc: '用生活化比喻解释一个复杂概念。', tag: '精选', rating: 4.8, sales: 3560, coverHeight: 202, contentType: 'prompt' }),
  createProduct({ id: 'ai-003', name: '旅行规划助手', desc: '根据出发地、预算、天数和兴趣，整理每日路线、交通、餐饮与避坑提醒。', tag: '推荐', rating: 4.9, sales: 6290, coverHeight: 154, contentType: 'assistant' }),
  createProduct({ id: 'ai-004', name: '三步拆解学习计划', desc: '把学习目标拆成阶段任务、每天行动和复盘问题，适合快速开始。', tag: '', rating: 4.7, sales: 2188, coverHeight: 120, contentType: 'prompt' }),
  createProduct({ id: 'ai-005', name: '代码审查搭档', desc: '从正确性、边界条件、类型安全、性能与可维护性五个角度审查代码，并给出可执行的修改建议。', tag: '开发者', rating: 4.9, sales: 4762, coverHeight: 226, contentType: 'assistant' }),
  createProduct({ id: 'ai-006', name: '把会议记录整理成行动项', desc: '提取负责人、截止时间、依赖和待确认问题，输出清晰表格。', tag: '效率', rating: 4.8, sales: 3901, coverHeight: 142, contentType: 'prompt' }),
  createProduct({ id: 'ai-007', name: '面试模拟官', desc: '选择岗位后开始逐轮追问，根据回答给出评分、薄弱点与下一轮训练建议。', tag: '热门', rating: 4.9, sales: 7355, coverHeight: 188, contentType: 'assistant' }),
  createProduct({ id: 'ai-008', name: '同一文案生成五种语气', desc: '把输入文案改写为专业、亲切、幽默、克制和热情五个版本。', tag: '', rating: 4.6, sales: 1834, coverHeight: 126, contentType: 'prompt' }),
  createProduct({ id: 'ai-009', name: '英语口语陪练', desc: '围绕真实生活场景展开对话，随时纠正表达并给出更自然的替换说法。', tag: '口语', rating: 4.8, sales: 5210, coverHeight: 214, contentType: 'assistant' }),
  createProduct({ id: 'ai-010', name: '用苏格拉底方式追问', desc: '不直接给答案，通过连续问题帮我澄清假设、证据与结论。', tag: '思考', rating: 4.8, sales: 2740, coverHeight: 150, contentType: 'prompt' }),
  createProduct({ id: 'ai-011', name: '周报生成器', desc: '把零散工作记录整理为本周进展、结果数据、风险、协作事项和下周计划。', tag: '效率', rating: 4.7, sales: 6682, coverHeight: 176, contentType: 'assistant' }),
  createProduct({ id: 'ai-012', name: '从反方视角检查方案', desc: '站在最严格的反对者立场，列出漏洞、失败条件和需要补充的证据。', tag: '精选', rating: 4.9, sales: 2461, coverHeight: 136, contentType: 'prompt' }),
  createProduct({ id: 'ai-013', name: '健身计划教练', desc: '根据训练经验、器械、每周时间和身体目标制定计划，并提供动作替代方案。', tag: '健康', rating: 4.7, sales: 4135, coverHeight: 220, contentType: 'assistant' }),
  createProduct({ id: 'ai-014', name: '生成结构化读书笔记', desc: '从核心观点、论据、案例、金句和行动启发五部分整理一篇读书笔记。', tag: '', rating: 4.8, sales: 3290, coverHeight: 146, contentType: 'prompt' }),
  createProduct({ id: 'ai-015', name: '菜谱灵感助手', desc: '告诉我冰箱里的食材，就能组合可行菜谱，说明步骤、用量和替换食材。', tag: '生活', rating: 4.6, sales: 5890, coverHeight: 196, contentType: 'assistant' }),
  createProduct({ id: 'ai-016', name: '将需求改写为用户故事', desc: '把模糊需求改写成用户故事、验收标准、异常场景与不做清单。', tag: '产品', rating: 4.9, sales: 2015, coverHeight: 124, contentType: 'prompt' }),
  createProduct({ id: 'ai-017', name: '阅读笔记管家', desc: '粘贴文章或读书摘录，自动归纳主题、建立知识卡片，并生成方便回顾的问题。', tag: '学习', rating: 4.8, sales: 4678, coverHeight: 208, contentType: 'assistant' }),
  createProduct({ id: 'ai-018', name: '一周内容选题日历', desc: '围绕一个账号定位生成七天选题，每天包含标题角度、内容结构和互动问题。', tag: '创作', rating: 4.7, sales: 3799, coverHeight: 160, contentType: 'prompt' }),
  createProduct({ id: 'ai-019', name: '产品需求分析师', desc: '分析需求价值、用户场景、范围边界、关键指标与潜在风险，帮你在开发前把问题想清楚。', tag: '产品', rating: 4.9, sales: 3156, coverHeight: 230, contentType: 'assistant' }),
  createProduct({ id: 'ai-020', name: '给代码补充边界测试', desc: '根据函数签名和实现列出关键边界，再生成正常、异常与回归测试案例。', tag: '开发者', rating: 4.8, sales: 2874, coverHeight: 138, contentType: 'prompt' }),
  createProduct({ id: 'ai-021', name: 'PPT 大纲助手', desc: '根据演讲对象、时间与目标，设计有叙事节奏的页面大纲和每页要点。', tag: '办公', rating: 4.7, sales: 4560, coverHeight: 182, contentType: 'assistant' }),
  createProduct({ id: 'ai-022', name: '把长文章压缩为知识卡片', desc: '保留关键结论、证据和上下文，把长文整理成可以逐张阅读与收藏的短卡片。', tag: '精选', rating: 4.8, sales: 3345, coverHeight: 128, contentType: 'prompt' }),
  createProduct({ id: 'ai-023', name: '简历优化顾问', desc: '针对目标岗位检查简历表达，量化成果，补齐关键词，并模拟招聘者的十秒快速筛选。', tag: '求职', rating: 4.9, sales: 7042, coverHeight: 218, contentType: 'assistant' }),
  createProduct({ id: 'ai-024', name: '模拟苛刻用户评审', desc: '以挑剔用户视角体验方案，指出理解成本、操作阻力和不可信的承诺。', tag: '思考', rating: 4.7, sales: 1689, coverHeight: 144, contentType: 'prompt' }),
  createProduct({ id: 'ai-025', name: '儿童故事创作助手', desc: '设置主角、年龄、主题和篇幅，生成温暖有趣、适合睡前阅读的原创故事。', tag: '亲子', rating: 4.8, sales: 3987, coverHeight: 204, contentType: 'assistant' }),
  createProduct({ id: 'ai-026', name: '生成旅行打包清单', desc: '结合目的地天气、旅行天数和活动类型，输出分类清单并标记容易遗漏的物品。', tag: '旅行', rating: 4.6, sales: 2490, coverHeight: 134, contentType: 'prompt' }),
  createProduct({ id: 'ai-027', name: '情绪复盘伙伴', desc: '用温和的问题陪你梳理发生了什么、当时的感受、真实需求和下一次可以尝试的行动。', tag: '陪伴', rating: 4.8, sales: 6108, coverHeight: 224, contentType: 'assistant' }),
  createProduct({ id: 'ai-028', name: '把目标拆成今天能做的事', desc: '将一个大目标拆成二十分钟内可以启动的小行动，并给出完成标准。', tag: '行动', rating: 4.9, sales: 5302, coverHeight: 148, contentType: 'prompt' })
]

export async function GET() {
  return NextResponse.json({
    code: 200,
    message: 'success',
    data: MOCK_PRODUCTS
  })
}
