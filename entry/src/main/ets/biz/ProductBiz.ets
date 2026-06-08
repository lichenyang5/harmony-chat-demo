import { ProductImp } from '../imp/ProductImp'
import { Product } from '../models/productModel'

/**
 * 商品业务层。
 *
 * imp 拿原始 ApiResponse；biz 这里做协议解包 + 失败兜底，
 * 上层 controller 只关心 Product[] 这种纯数据，不用关心 code/message。
 */
export class ProductBiz {
  private imp: ProductImp = new ProductImp()

  list(): Promise<Product[]> {
    return this.imp.list().then((res) => {
      if (res.code === 200 && res.data) {
        return res.data
      }
      return [] as Product[]
    })
  }
}
