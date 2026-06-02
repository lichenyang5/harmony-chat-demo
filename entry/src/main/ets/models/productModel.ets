export class Product {
  id: string = ''
  name: string = ''
  price: number = 0
  desc: string = ''
  tag: string = ''   // 角标：'热门' | '新品' | '推荐' | ''
}

// ---- Mock 数据 ----
function makeProduct(id: string, name: string, price: number, desc: string, tag: string): Product {
  const p = new Product()
  p.id = id
  p.name = name
  p.price = price
  p.desc = desc
  p.tag = tag
  return p
}

export const MOCK_PRODUCTS: Product[] = [
  makeProduct('001', 'ArkTS 快速入门', 99,  '鸿蒙原生开发语言全解析', '新品'),
  makeProduct('002', 'HarmonyOS 实战', 299, '从零到项目上线完整教程', '热门'),
  makeProduct('003', 'ArkUI 组件精讲', 199, '企业级 UI 组件与布局', '推荐'),
  makeProduct('004', 'DevEco 效率指南', 49,  'IDE 调试与性能优化技巧', ''),
  makeProduct('005', 'ArkUI 动画教程', 149, '帧动画/转场/自定义动效', '精品'),
  makeProduct('006', '鸿蒙面试题库', 79,   '高频知识点与答题技巧',  '必备'),
]
