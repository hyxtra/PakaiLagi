export enum ItemStatus {
  AVAILABLE = "AVAILABLE",
  REQUESTED = "REQUESTED",
  RESERVED = "RESERVED",
  COMPLETED = "COMPLETED",
}

export enum RequestStatus {
  PENDING = "PENDING",
  ACCEPTED = "ACCEPTED",
  REJECTED = "REJECTED",
}

export enum DeliveryMethod {
  AMBIL_LANGSUNG = "AMBIL_LANGSUNG",
  BERTEMU = "BERTEMU",
  KURIR = "KURIR",
}

export interface Profile {
  Id: string;
  FullName: string;
  PhoneNumber: string | null;
  AvatarUrl: string | null;
  CreatedAt: string;
}

export interface Item {
  Id: string;
  OwnerId: string;
  Title: string;
  Description: string;
  Category: string;
  Status: ItemStatus;
  ImageUrl: string;
  CreatedAt: string;
}

export interface ItemRequest {
  Id: string;
  ItemId: string;
  RequesterId: string;
  Status: RequestStatus;
  DeliveryMethod: DeliveryMethod;
  CreatedAt: string;
}

export interface CreateItemDto {
  Title: string;
  Description: string;
  Category: string;
  ImageUrl: string;
}

export interface CreateRequestDto {
  ItemId: string;
  DeliveryMethod: DeliveryMethod;
}
