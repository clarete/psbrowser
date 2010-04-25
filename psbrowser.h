/* main.c - This file is part of the psbrowser program
 *
 * Copyright (C) 2010  Lincoln de Sousa <lincoln@comum.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _PSBROWSER_H_
#define _PSBROWSER_H_

typedef struct ps_command ps_command_t;

typedef struct ps_ctx ps_ctx_t;

typedef void   (*ps_callback_t) (ps_ctx_t *,     /* psbrowser context */
                                 ps_command_t *, /* command */
                                 char **,        /* Params */
                                 int nparams,    /* Number of recv params */
                                 void *data);    /* User data slot */

#endif  /* _PSBROWSER_H_ */
