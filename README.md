<h1>Pasos para generar el bucket</h1>

1. aws s3api create-bucket --bucket "olimpo-ablyk" --region "us-east-2"--create-bucket-configuration LocationConstraint="us-east-2"

2. aws s3api put-public-access-block --bucket olimpo-ablyk --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

3. aws s3api put-bucket-encryption --bucket olimpo-ablyk --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'

4. aws dynamodb create-table --table-name olimpo-terraform-state-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-2

borrar tabla por si te equivocas
aws dynamodb delete-table --table-name terraform-state-lock --region us-east-1
