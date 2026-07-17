import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
  import { Public } from '../../../common/decorators/public.decorator';
import { ConsultasLogic } from '../logic/consultas.logic';
import { DniParamDto, RucParamDto } from '../dto/consultas-param.dto';

@ApiTags('Consultas SUNAT/RENIEC')
@Controller('consultas')
export class ConsultasController {
  constructor(private readonly consultasLogic: ConsultasLogic) {}

  @Get('dni/:dni')
  @Public()
  @ApiOperation({ summary: 'Consultar nombres por DNI (RENIEC)' })
  consultarDni(@Param() params: DniParamDto) {
    return this.consultasLogic.consultarDni(params.dni);
  }

  @Get('ruc/:ruc')
  @Public()
  @ApiOperation({ summary: 'Consultar razón social por RUC (SUNAT)' })
  consultarRuc(@Param() params: RucParamDto) {
    return this.consultasLogic.consultarRuc(params.ruc);
  }
}
