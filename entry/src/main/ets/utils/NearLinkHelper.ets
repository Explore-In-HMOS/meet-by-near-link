import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessCard, DOMAIN_ID, LOG_TAG } from '../model/NearLinkModels';

const textEncoder = new util.TextEncoder();
const textDecoder = new util.TextDecoder('utf-8');

export class NearLinkHelper {
  static encodeData(data: object): Uint8Array {
    return textEncoder.encodeInto(JSON.stringify(data));
  }

  static decodeData(buffer: ArrayBuffer): BusinessCard | undefined {
    try {
      const uint8 = new Uint8Array(buffer);
      const text = textDecoder.decodeToString(uint8);
      hilog.info(DOMAIN_ID, LOG_TAG, `RAW DATA: ${text}`);
      return JSON.parse(text) as BusinessCard;
    } catch (e) {
      hilog.error(DOMAIN_ID, LOG_TAG, `decodeData error: ${JSON.stringify(e)}`);
      return undefined;
    }
  }

  static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}