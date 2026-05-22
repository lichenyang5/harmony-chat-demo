import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { ChatMessage } from '../models/ChatModel'

interface ChatCacheData {
  conversationId: number
  chatList: ChatMessage[]
}

export class ChatStorage {
  private static readonly STORE_NAME: string = 'chat_storage'
  private static readonly CHAT_CACHE_KEY: string = 'chat_cache'

  static async saveChatCache(
    context: common.UIAbilityContext,
    conversationId: number,
    chatList: ChatMessage[]
  ): Promise<void> {
    const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)

    const cacheData: ChatCacheData = {
      conversationId,
      chatList
    }

    await pref.put(ChatStorage.CHAT_CACHE_KEY, JSON.stringify(cacheData))
    await pref.flush()
  }

  static async getChatCache(context: common.UIAbilityContext): Promise<ChatCacheData> {
    const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)
    const cacheValue = await pref.get(ChatStorage.CHAT_CACHE_KEY, '')

    if (typeof cacheValue !== 'string' || cacheValue.length === 0) {
      return {
        conversationId: 0,
        chatList: []
      }
    }

    try {
      const cacheData = JSON.parse(cacheValue) as ChatCacheData

      return {
        conversationId: cacheData.conversationId || 0,
        chatList: cacheData.chatList || []
      }
    } catch (error) {
      console.error(`parse chat cache error: ${JSON.stringify(error)}`)

      return {
        conversationId: 0,
        chatList: []
      }
    }
  }

  static async clearChatCache(context: common.UIAbilityContext): Promise<void> {
    const pref = await preferences.getPreferences(context, ChatStorage.STORE_NAME)
    await pref.delete(ChatStorage.CHAT_CACHE_KEY)
    await pref.flush()
  }
}