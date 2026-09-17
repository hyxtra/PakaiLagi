CREATE TYPE "ItemStatus" AS ENUM ('AVAILABLE', 'REQUESTED', 'RESERVED', 'COMPLETED');
CREATE TYPE "RequestStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');
CREATE TYPE "DeliveryMethod" AS ENUM ('AMBIL_LANGSUNG', 'BERTEMU', 'KURIR');


CREATE TABLE "Profile" (
    "Id" UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    "FullName" TEXT NOT NULL,
    "PhoneNumber" TEXT,
    "AvatarUrl" TEXT,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "Item" (
    "Id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "OwnerId" UUID NOT NULL REFERENCES "Profile"("Id") ON DELETE CASCADE,
    "Title" TEXT NOT NULL,
    "Description" TEXT NOT NULL,
    "Category" TEXT NOT NULL,
    "Status" "ItemStatus" NOT NULL DEFAULT 'AVAILABLE',
    "ImageUrl" TEXT NOT NULL,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE "ItemRequest" (
    "Id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "ItemId" UUID NOT NULL REFERENCES "Item"("Id") ON DELETE CASCADE,
    "RequesterId" UUID NOT NULL REFERENCES "Profile"("Id") ON DELETE CASCADE,
    "Status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "DeliveryMethod" "DeliveryMethod" NOT NULL,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_item_owner ON "Item"("OwnerId");
CREATE INDEX idx_item_status ON "Item"("Status");
CREATE INDEX idx_request_item ON "ItemRequest"("ItemId");
CREATE INDEX idx_request_requester ON "ItemRequest"("RequesterId");


ALTER TABLE "Profile" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Item" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ItemRequest" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profile_select_authenticated"
    ON "Profile" FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "profile_update_own"
    ON "Profile" FOR UPDATE
    TO authenticated
    USING (auth.uid() = "Id")
    WITH CHECK (auth.uid() = "Id");


CREATE POLICY "item_select_available"
    ON "Item" FOR SELECT
    TO authenticated
    USING ("Status" = 'AVAILABLE' OR "OwnerId" = auth.uid());

CREATE POLICY "item_insert_authenticated"
    ON "Item" FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = "OwnerId");

CREATE POLICY "item_update_own"
    ON "Item" FOR UPDATE
    TO authenticated
    USING (auth.uid() = "OwnerId")
    WITH CHECK (auth.uid() = "OwnerId");

CREATE POLICY "item_delete_own"
    ON "Item" FOR DELETE
    TO authenticated
    USING (auth.uid() = "OwnerId");


CREATE POLICY "request_select_requester"
    ON "ItemRequest" FOR SELECT
    TO authenticated
    USING (
        "RequesterId" = auth.uid()
        OR EXISTS (
            SELECT 1 FROM "Item"
            WHERE "Item"."Id" = "ItemRequest"."ItemId"
            AND "Item"."OwnerId" = auth.uid()
        )
    );

CREATE POLICY "request_insert_authenticated"
    ON "ItemRequest" FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = "RequesterId");

CREATE POLICY "request_update_owner"
    ON "ItemRequest" FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM "Item"
            WHERE "Item"."Id" = "ItemRequest"."ItemId"
            AND "Item"."OwnerId" = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM "Item"
            WHERE "Item"."Id" = "ItemRequest"."ItemId"
            AND "Item"."OwnerId" = auth.uid()
        )
    );


INSERT INTO storage.buckets (id, name, public)
VALUES ('item-images', 'item-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "item_images_select_public"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'item-images');

CREATE POLICY "item_images_insert_authenticated"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'item-images');

CREATE POLICY "item_images_delete_own"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'item-images'
        AND (storage.foldername(name))[1] = 'items'
        AND (storage.foldername(name))[2] = auth.uid()::text
    );


CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    INSERT INTO public."Profile" ("Id", "FullName")
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', '')
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
