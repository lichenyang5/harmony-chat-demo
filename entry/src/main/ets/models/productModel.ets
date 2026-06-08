/**
 * 商品模型。
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
}
