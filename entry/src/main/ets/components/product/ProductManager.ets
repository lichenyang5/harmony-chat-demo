import { HMRouterMgr } from '@hadss/hmrouter'
import { Product } from '../../models/Product'
import { ProductStore, productStore } from '../../stores/ProductStore'
import { RouteConstants } from '../../constants/RouteConstants'
interface ProductDetailParam {
  id: number
  title: string
  from: string
}
@ComponentV2
export struct ProductManager {
  @Param from: string = '默认入口'

  @Local inputKeyword: string = ''
  @Local searchKeyword: string = ''
  @Local newName: string = ''
  @Local editingId: number = -1
  @Local editingName: string = ''
  @Local store: ProductStore = productStore

  aboutToAppear(): void {
    this.store.initProducts()
  }

  private addProduct(): void {
    const name = this.newName.trim()

    if (name.length === 0) {
      return
    }

    this.store.addProduct(name)
    this.newName = ''
  }

  private deleteProduct(id: number): void {
    this.store.deleteProduct(id)
  }

  private startEditProduct(item: Product): void {
    this.editingId = item.id
    this.editingName = item.name
  }

  private saveEditProduct(): void {
    const name = this.editingName.trim()

    if (this.editingId < 0 || name.length === 0) {
      return
    }

    this.store.updateProductName(this.editingId, name)

    this.editingId = -1
    this.editingName = ''
  }

  private getShowProducts(key: string): Product[] {
    if (key.length === 0) {
      return this.store.products
    }

    return this.store.products.filter((item: Product) => {
      return item.name.includes(key)
    })
  }

  private openDetail(item: Product): void {
    const params: ProductDetailParam = {
      id: item.id,
      title: item.name,
      from: '商品列表'
    }

    console.log('跳转详情页参数：' + JSON.stringify(params))

    HMRouterMgr.push({
      pageUrl: RouteConstants.PRODUCT_DETAIL,
      param: params
    })
  }
  build() {
    Column({ space: 12 }) {
      Text('商品管理')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)

      Text(`从哪里来：${this.from}`)
        .fontSize(14)
        .fontColor('#666666')

      Row({ space: 8 }) {
        TextInput({
          placeholder: '搜索商品',
          text: $$this.inputKeyword
        })
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)

        Button('搜索')
          .height(44)
          .onClick(() => {
            this.searchKeyword = this.inputKeyword.trim()
          })

        Button('重置')
          .height(44)
          .onClick(() => {
            this.inputKeyword = ''
            this.searchKeyword = ''
          })
      }
      .width('100%')

      if (this.editingId >= 0) {
        Row({ space: 8 }) {
          TextInput({
            placeholder: '修改商品名称',
            text: $$this.editingName
          })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#FFF7E6')
            .borderRadius(8)

          Button('保存')
            .height(44)
            .onClick(() => {
              this.saveEditProduct()
            })

          Button('取消')
            .height(44)
            .onClick(() => {
              this.editingId = -1
              this.editingName = ''
            })
        }
        .width('100%')
      }

      Row({ space: 8 }) {
        TextInput({
          placeholder: '请输入商品名称',
          text: $$this.newName
        })
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)

        Button('新增')
          .height(44)
          .onClick(() => {
            this.addProduct()
          })
      }
      .width('100%')

      Text(`共 ${this.getShowProducts(this.searchKeyword.trim()).length} 个商品`)
        .fontSize(14)

      ForEach(this.getShowProducts(this.searchKeyword.trim()), (item: Product) => {
        Row({ space: 8 }) {
          Column() {
            Text(item.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)

            Text(`￥${item.price} | 库存：${item.stock}`)
              .fontSize(12)
              .fontColor('#666666')
          }
          .layoutWeight(2)
          .alignItems(HorizontalAlign.Start)
          .onClick(() => {
            this.openDetail(item)
          })

          Button('详情')
            .height(44)
            .onClick(() => {
              this.openDetail(item)
            })
            .layoutWeight(1)

          Button('改名')
            .height(44)
            .onClick(() => {
              this.startEditProduct(item)
            })
            .layoutWeight(1)

          Button('删除')
            .height(44)
            .onClick(() => {
              this.deleteProduct(item.id)
            })
            .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
      }, (item: Product) => `${item.id}-${item.name}-${item.price}-${item.stock}`)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F7F7F7')
    .alignItems(HorizontalAlign.Start)
  }
}