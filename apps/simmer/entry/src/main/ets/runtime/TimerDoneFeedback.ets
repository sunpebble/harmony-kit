import { vibrator } from '@kit.SensorServiceKit'

export class TimerDoneFeedback {
  // 到点触感反馈。真机会振动；模拟器无振动硬件，任一步抛错都静默失败。
  // 可见的 done 状态（黄环 + overdue 计数 + toast）始终是 source of truth。
  static async fire(): Promise<void> {
    try {
      await vibrator.startVibration({ type: 'preset', effectId: 'haptic.effect.scene3' }, { usage: 'notification' })
      return
    } catch (_error) {
      // haptic.effect.scene3 在当前设备/模拟器不可用，降级到时长振动。
    }
    try {
      await vibrator.startVibration({ type: 'time', duration: 200 }, { usage: 'notification' })
    } catch (_error) {
      // duration 振动也不可用（模拟器无硬件），静默失败。
    }
    // 系统铃声：API 23 实现阶段 systemSoundManager / ringtoneManager 适配待确认，
    // 模拟器本就无铃声硬件，先用振动，铃声暂跳过。
  }
}
