/**
 * 首页内容模型。沿用 Product 名称以兼容收藏、详情和购物车链路。
 *
 * 注意：旧版项目用 MOCK_PRODUCTS 写死数据；接入 /api/products 接口后
 * 已移除，商品列表统一由 HomeController.loadProducts() 拉取。
 */
export class Product {
  id: string = ''              // id
  name: string = ''            // 商品名称
  price: number = 0            // 当前价格
  desc: string = ''            // 商品描述
  image: string = ''           // 商品图片（rawfile 路径，形如 'images/1.png'）
  originalPrice: number = 0    // 原价
  tag: string = ''             // 新品 / 热门 / 推荐 / 必备 等角标
  rating: number = 0           // 评分
  sales: number = 0            // 销量
  stock: number = 0            // 库存
  coverHeight: number = 140    // 首页瀑布流封面高度
  contentType: string = 'prompt' // prompt：提示词；assistant：AI 助手模板
}
