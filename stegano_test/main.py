import streamlit as st
from PIL import Image
import numpy as np
import piexif
import json
import io


# Function to convert DMS (Degrees, Minutes, Seconds) to Decimal Degrees
def dms_to_decimal(dms, ref):
    degrees = dms[0][0] / dms[0][1]
    minutes = dms[1][0] / dms[1][1]
    seconds = dms[2][0] / dms[2][1]
    decimal = degrees + minutes / 60 + seconds / 3600
    if ref in ['S', 'W']:
        decimal = -decimal
    return decimal

# Function to extract metadata from image
def extract_metadata(image):
    exif_dict = piexif.load(image.info.get("exif", b""))
    metadata = {}

    datetime_bytes = exif_dict["0th"].get(piexif.ImageIFD.DateTime, b'')
    metadata["DateTime"] = datetime_bytes.decode('utf-8', 'ignore')

    gps = exif_dict.get("GPS", {})
    if gps:
        decoded_gps = {}
        for tag, value in gps.items():
            tag_name = str(tag)
            if isinstance(value, bytes):
                try:
                    decoded_gps[tag_name] = value.decode('utf-8', 'ignore')
                except:
                    decoded_gps[tag_name] = str(value)
            else:
                decoded_gps[tag_name] = value
        metadata["GPSInfo"] = decoded_gps

    return metadata

# Function to encode metadata into image
def encode_metadata(image, metadata):
    metadata_str = json.dumps(metadata)
    binary_data = ''.join(format(ord(i), '08b') for i in metadata_str)
    binary_data += '1111111111111110'

    img = image.convert('RGB')
    data = np.array(img)
    flat_data = data.flatten()

    if len(binary_data) > len(flat_data):
        raise ValueError("Image too small to encode data.")

    for i in range(len(binary_data)):
        flat_data[i] = (flat_data[i] & 0b11111110) | int(binary_data[i])

    new_data = flat_data.reshape(data.shape)
    encoded_img = Image.fromarray(new_data.astype(np.uint8))
    return encoded_img

# Function to decode metadata from image
def decode_metadata(image):
    img = image.convert('RGB')
    data = np.array(img).flatten()

    binary_str = ''
    for i in range(len(data)):
        binary_str += str(data[i] & 1)
        if binary_str.endswith('1111111111111110'):
            break

    binary_str = binary_str[:-16]
    chars = [chr(int(binary_str[i:i+8], 2)) for i in range(0, len(binary_str), 8)]
    metadata_str = ''.join(chars)

    try:
        metadata = json.loads(metadata_str)
        return metadata
    except:
        return {}

# Streamlit app
st.set_page_config(page_title="Image Metadata Steganography", page_icon="🖼️", layout="wide")
st.title("Image Metadata Steganography")

menu = st.sidebar.radio("Choose Mode", ["Encode Metadata", "Decode Metadata"])

if menu == "Encode Metadata":
    st.header("📥 Upload an Image to Encode Metadata")
    uploaded_file = st.file_uploader("Choose an image", type=["jpg", "jpeg", "png"])

    if uploaded_file:
        image = Image.open(uploaded_file)
        st.image(image, caption="Original Image", use_container_width=True)

        try:
            metadata = extract_metadata(image)
            if not metadata:
                st.warning("No EXIF metadata found in this image.")
            else:
                st.subheader("Extracted Metadata:")
                st.json(metadata)

                if st.button("🔐 Encode Metadata"):
                    encoded_img = encode_metadata(image, metadata)

                    # Save to buffer
                    buf = io.BytesIO()
                    encoded_img.save(buf, format="PNG")
                    byte_im = buf.getvalue()

                    st.success("Metadata encoded successfully!")
                    st.download_button("⬇️ Download Encoded Image", byte_im, file_name="encoded_image.png", mime="image/png")
        except Exception as e:
            st.error(f"Error: {e}")

elif menu == "Decode Metadata":
    st.header("📥 Upload an Image to Decode Hidden Metadata")
    decode_file = st.file_uploader("Choose an image to decode", type=["png", "jpg", "jpeg"])

    if decode_file:
        image = Image.open(decode_file)
        st.image(image, caption="Uploaded Image", use_container_width=True)

        metadata = decode_metadata(image)

        if metadata:
            st.subheader("Date/Time")
            st.write(metadata.get("DateTime", "Not available"))

            gps = metadata.get("GPSInfo", {})
            if gps and "2" in gps and "4" in gps:
                try:
                    lat = dms_to_decimal(gps["2"], gps["1"])
                    lon = dms_to_decimal(gps["4"], gps["3"])
                    st.subheader("GPS Coordinates")
                    st.write(f"**Latitude:** {lat:.6f}° {gps['1']}")
                    st.write(f"**Longitude:** {lon:.6f}° {gps['3']}")
                except Exception as e:
                    st.warning("GPS data found but could not be parsed.")
            else:
                st.info("No valid GPS data found.")
