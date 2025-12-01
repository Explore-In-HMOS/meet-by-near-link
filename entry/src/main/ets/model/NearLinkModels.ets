export const MANUFACTURER_ID: number = 4567;
export const SERVICE_UUID: string = '37BEA880-FC70-11EA-B720-00000000060D';
export const LOG_TAG: string = 'NearlinkCardShare';
export const DOMAIN_ID: number = 0x0000;

export interface BusinessCard {
  fullName: string;
  title: string;
  company: string;
  phone: string;
  email: string;
  shareDate: number;
}

export interface SimpleDevice {
  address: string;
  name: string;
  rssi: number;
}