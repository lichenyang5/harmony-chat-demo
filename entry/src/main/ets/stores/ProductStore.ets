import { Product } from '../models/Product'

@ObservedV2
export class ProductStore {
  @Trace products: Product[] = []

  initProducts(): void {
    if (this.products.length > 0) {
      return
    }

    const p1 = new Product()
    p1.id = 1
    p1.name = '苹果'
    p1.price = 5
    p1.stock = 100
    p1.desc = '新鲜红苹果，适合日常购买'

    const p2 = new Product()
    p2.id = 2
    p2.name = '香蕉'
    p2.price = 3
    p2.stock = 80
    p2.desc = '软糯香甜，适合早餐'

    const p3 = new Product()
    p3.id = 3
    p3.name = '牛奶'
    p3.price = 12
    p3.stock = 50
    p3.desc = '早餐搭配，补充蛋白质'

    this.products = [p1, p2, p3]
  }

  addProduct(name: string): void {
    const p = new Product()
    p.id = Date.now()
    p.name = name
    p.price = Math.floor(Math.random() * 20) + 1
    p.stock = Math.floor(Math.random() * 100) + 1
    p.desc = '这是一个新增商品'

    this.products = [...this.products, p]
  }

  deleteProduct(id: number): void {
    this.products = this.products.filter((item: Product) => {
      return item.id !== id
    })
  }

  updateProductName(id: number, name: string): void {
    this.products = this.products.map((item: Product) => {
      if (item.id === id) {
        const p = new Product()
        p.id = item.id
        p.name = name
        p.price = item.price
        p.stock = item.stock
        p.desc = item.desc
        return p
      }
      return item
    })
  }

  findProductById(id: number): Product | undefined {
    return this.products.find((item: Product) => {
      return item.id === id
    })
  }
}

export const productStore: ProductStore = new ProductStore()