export class Product {
  id: string = ''              // id
  name: string = ''            // 商品名称
  price: number = 0            // 当前价格
  desc: string = ''            // 商品描述
  image: string = ''           // 商品图片
  originalPrice: number = 0    // 原价
  tag: string = ''             // 热门 / 新品 / 推荐
  rating: number = 0           // 评分
  sales: number = 0            // 销量
  stock: number = 0            // 库存
}

// ---- Mock 数据 ----
function makeProduct(
  id: string,
  name: string,
  price: number,
  originalPrice: number,
  desc: string,
  tag: string,
  rating: number,
  sales: number,
  stock: number
): Product {
  const p = new Product()

  p.id = id
  p.name = name
  p.price = price
  p.originalPrice = originalPrice
  p.desc = desc

  // 根据商品ID生成固定图片
  p.image = `images/1.png`

  p.tag = tag
  p.rating = rating
  p.sales = sales
  p.stock = stock

  return p
}

export const MOCK_PRODUCTS: Product[] = [
  makeProduct(
    '001',
    'ArkTS 快速入门',
    99,
    129,
    '鸿蒙原生开发语言全解析',
    '新品',
    4.8,
    1256,
    98
  ),

  makeProduct(
    '002',
    'HarmonyOS 实战',
    299,
    399,
    '从零到项目上线完整教程',
    '热门',
    4.9,
    3280,
    56
  ),

  makeProduct(
    '003',
    'ArkUI 组件精讲',
    199,
    259,
    '企业级 UI 组件与布局',
    '推荐',
    4.7,
    1845,
    120
  ),

  makeProduct(
    '004',
    'DevEco 效率指南',
    49,
    79,
    'IDE 调试与性能优化技巧',
    '',
    4.6,
    932,
    200
  ),

  makeProduct(
    '005',
    'ArkUI 动画教程',
    149,
    199,
    '帧动画、转场与自定义动效',
    '热门',
    4.8,
    1568,
    85
  ),

  makeProduct(
    '006',
    '鸿蒙面试题库',
    79,
    99,
    '高频知识点与答题技巧',
    '必备',
    4.9,
    5120,
    300
  ),

  makeProduct(
    '007',
    'HMRouter 路由实战',
    89,
    119,
    '路由跳转与参数传递',
    '新品',
    4.7,
    643,
    150
  ),

  makeProduct(
    '008',
    'ArkWeb 开发指南',
    129,
    169,
    'Web 与原生混合开发',
    '推荐',
    4.8,
    890,
    110
  ),

  makeProduct(
    '009',
    '鸿蒙网络请求实战',
    69,
    99,
    'HTTP、SSE、上传下载',
    '热门',
    4.8,
    2341,
    180
  ),

  makeProduct(
    '010',
    'ArkData 持久化指南',
    119,
    159,
    'Preferences 与数据库实践',
    '推荐',
    4.6,
    721,
    140
  ),

  makeProduct(
    '011',
    '企业级鸿蒙架构设计',
    399,
    499,
    'MVVM 与模块化架构实战',
    '精品',
    5.0,
    980,
    36
  ),

  makeProduct(
    '012',
    '鸿蒙项目源码合集',
    199,
    299,
    '多个完整项目案例源码',
    '热销',
    4.9,
    2860,
    75
  )
]