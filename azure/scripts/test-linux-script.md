# Test Linux Script

## Các sửa đổi đã thực hiện trong setup-infrastructure.sh:

### 1. Sửa function `configure_kubectl()`
- **Trước**: `aks_name="${PROJECT_NAME}-${ENVIRONMENT}-aks"` → `nash-pisharp-demo-aks`
- **Sau**: `aks_name="aks-${PROJECT_NAME}"` → `aks-nash-pisharp`
- **Trước**: `resource_group="${PROJECT_NAME}-${ENVIRONMENT}-rg"` → `nash-pisharp-demo-rg`  
- **Sau**: `resource_group="rg-${PROJECT_NAME}-${ENVIRONMENT}"` → `rg-nash-pisharp-demo`

### 2. Cập nhật function `setup_terraform_backend()`
- Loại bỏ việc tạo file backend.tf riêng biệt
- Sử dụng backend-state-management.tf có sẵn
- Đảm bảo tên storage account khớp với PowerShell script

### 3. Thêm setup backend cho Plan command
- Plan command bây giờ sẽ tạo backend storage account trước khi chạy terraform init

## Test commands:

```bash
# Make script executable
chmod +x azure/scripts/setup-infrastructure.sh

# Test plan command
./azure/scripts/setup-infrastructure.sh plan -e demo -s d9998de9-2d0d-4408-a036-55f320f28f20

# Test setup command  
./azure/scripts/setup-infrastructure.sh setup -e demo -s d9998de9-2d0d-4408-a036-55f320f28f20

# Test validate command
./azure/scripts/setup-infrastructure.sh validate

# Test output command
./azure/scripts/setup-infrastructure.sh output
```

## Các thay đổi tương đương với PowerShell script:

1. ✅ **Backend storage account naming**: Đồng bộ với PowerShell
2. ✅ **AKS cluster naming**: Sử dụng format `aks-{project_name}`  
3. ✅ **Resource group naming**: Sử dụng format `rg-{project_name}-{environment}`
4. ✅ **Plan command**: Thêm setup backend trước khi init
5. ✅ **kubectl configuration**: Sử dụng tên đúng cho cluster và RG