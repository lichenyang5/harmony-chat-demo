import { ApiConstants, ApiResponse, HttpUtil } from 'common'
import { Product } from '../models/productModel'

/**
 * 商品远程数据源实现。
 * 对应服务端：GET /api/products → { code, message, data: Product[] }
 */
export class ProductImp {
  list(): Promise<ApiResponse<Product[]>> {
    return HttpUtil.get<Product[]>(ApiConstants.PRODUCTS)
  }
}
